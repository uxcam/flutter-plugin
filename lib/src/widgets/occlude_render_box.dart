import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_models.dart';
import 'occlusion_registry.dart';

class TimestampedBounds {
  final int timestampMs;
  final Rect bounds;
  const TimestampedBounds(this.timestampMs, this.bounds);
}

class OccludeRenderBox extends RenderProxyBox
    implements OcclusionReportingRenderBox {
  OccludeRenderBox({
    required bool enabled,
    required OcclusionType type,
    required this.registry,
  })  : _enabled = enabled,
        _type = type;

  final OcclusionRegistry registry;

  late final int _stableId = _generateStableId();
  static int _idCounter = 0;
  static int _generateStableId() {
    return Object.hash(++_idCounter, DateTime.now().microsecondsSinceEpoch);
  }

  BuildContext? _context;
  Rect? _lastReportedBounds;
  bool _enabled;
  OcclusionType _type;
  bool _isRegistered = false;

  /// Sliding window of bounds from last 50ms to handle rasterization lag.
  static const int _boundsWindowMs = 50;
  final _timestampedBounds = <TimestampedBounds>[];

  ModalRoute<dynamic>? _trackedRoute;
  bool _isRouteVisible = true;

  bool get _shouldReport => _enabled && _isRouteVisible;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _calculateAndReportBounds();
    if (_enabled) markNeedsPaint();
  }

  OcclusionType get type => _type;
  set type(OcclusionType value) {
    if (_type == value) return;
    _type = value;
    markNeedsPaint();
  }

  void updateContext(BuildContext context) {
    _context = context;
    _setupRouteListener(context);
  }

  void _setupRouteListener(BuildContext context) {
    _detachFromRoute();

    final route = ModalRoute.of(context);
    if (route != null) {
      _trackedRoute = route;
      route.animation?.addListener(_onRouteAnimationTick);
      route.secondaryAnimation?.addListener(_onRouteAnimationTick);
      route.secondaryAnimation?.addStatusListener(_onSecondaryAnimationStatus);

      if (route.isCurrent) {
        _updateRouteVisibility(true);
      } else {
        _checkIfCoveredByOpaqueRoute();
      }
    } else {
      _updateRouteVisibility(true);
    }
  }

  void _detachFromRoute() {
    _trackedRoute?.animation?.removeListener(_onRouteAnimationTick);
    _trackedRoute?.secondaryAnimation?.removeListener(_onRouteAnimationTick);
    _trackedRoute?.secondaryAnimation
        ?.removeStatusListener(_onSecondaryAnimationStatus);
    _trackedRoute = null;
  }

  void _onRouteAnimationTick() {
    if (!attached) return;
    markNeedsPaint();
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _checkIfCoveredByOpaqueRoute();
    } else if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _updateRouteVisibility(true);
      if (status == AnimationStatus.dismissed) {
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          if (attached && _isRouteVisible) {
            markNeedsPaint();
          }
        });
      }
    }
  }

  void _checkIfCoveredByOpaqueRoute() {
    if (_context == null || _trackedRoute == null) return;

    final navigator = Navigator.maybeOf(_context!);
    if (navigator == null) return;

    bool hasOpaqueRouteAbove = false;

    navigator.popUntil((route) {
      if (route == _trackedRoute) {
        return true;
      }
      if (route is ModalRoute && route.opaque) {
        hasOpaqueRouteAbove = true;
      }
      return true;
    });

    _updateRouteVisibility(!hasOpaqueRouteAbove);
  }

  void _updateRouteVisibility(bool visible) {
    if (_isRouteVisible == visible) return;
    _isRouteVisible = visible;
    _calculateAndReportBounds();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (!_isRegistered) {
      _isRegistered = true;
      registry.register(this);
    }
  }

  @override
  void detach() {
    _detachFromRoute();
    if (_isRegistered) {
      _isRegistered = false;
      registry.unregister(this);
    }
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _calculateAndReportBounds();
  }

  void _calculateAndReportBounds() {
    if (!attached || !hasSize) return;

    if (!_shouldReport) {
      _lastReportedBounds = null;
      if (_isRegistered) {
        _isRegistered = false;
        registry.unregister(this);
      }
      return;
    }

    final transform = getTransformTo(null);
    final rawBounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    final effectiveClip = _calculateEffectiveClip();
    Rect? finalBounds;

    if (effectiveClip != null) {
      final intersection = rawBounds.intersect(effectiveClip);

      final rawArea = rawBounds.width * rawBounds.height;
      final clippedArea = intersection.width > 0 && intersection.height > 0
          ? intersection.width * intersection.height
          : 0.0;
      final visibleRatio = rawArea > 0 ? clippedArea / rawArea : 0.0;

      if (clippedArea <= 0) {
        // Completely clipped - keep last bounds for scroll coverage
        return;
      } else if (visibleRatio < 0.5) {
        // Mostly clipped - use raw bounds for over-occlusion
        finalBounds = rawBounds;
      } else {
        finalBounds = intersection;
      }
    } else {
      finalBounds = rawBounds;
    }

    if (!_isRegistered) {
      _isRegistered = true;
      registry.register(this);
    }

    final devicePixelRatio = _getDevicePixelRatio();
    final snappedBounds = _snapToDevicePixels(finalBounds, devicePixelRatio);

    if (!_rectsEqualWithinTolerance(_lastReportedBounds, snappedBounds)) {
      _lastReportedBounds = snappedBounds;
    }
  }

  Rect? _calculateEffectiveClip() {
    Rect? clip;

    RenderObject? current = parent;
    while (current != null) {
      if (current is RenderClipRect ||
          current is RenderClipRRect ||
          current is RenderClipPath ||
          current is RenderViewport ||
          current is RenderAbstractViewport) {
        clip = _intersectClip(clip, current as RenderBox);
      }
      current = current.parent;
    }

    return clip;
  }

  Rect? _intersectClip(Rect? existing, RenderBox clipper) {
    final clipperTransform = clipper.getTransformTo(null);
    final clipperBounds =
        MatrixUtils.transformRect(clipperTransform, Offset.zero & clipper.size);

    if (existing == null) {
      return clipperBounds;
    }
    return existing.intersect(clipperBounds);
  }

  double _getDevicePixelRatio() {
    if (_context != null) {
      final view = View.maybeOf(_context!);
      if (view != null) return view.devicePixelRatio;
    }
    return WidgetsBinding
        .instance.platformDispatcher.views.first.devicePixelRatio;
  }

  int _getViewId() {
    if (_context != null) {
      final view = View.maybeOf(_context!);
      if (view != null) return view.viewId;
    }
    return 0;
  }

  Rect _snapToDevicePixels(Rect rect, double devicePixelRatio) {
    return Rect.fromLTRB(
      (rect.left * devicePixelRatio).roundToDouble() / devicePixelRatio,
      (rect.top * devicePixelRatio).roundToDouble() / devicePixelRatio,
      (rect.right * devicePixelRatio).roundToDouble() / devicePixelRatio,
      (rect.bottom * devicePixelRatio).roundToDouble() / devicePixelRatio,
    );
  }

  bool _rectsEqualWithinTolerance(Rect? a, Rect? b, [double tolerance = 0.5]) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() < tolerance &&
        (a.top - b.top).abs() < tolerance &&
        (a.right - b.right).abs() < tolerance &&
        (a.bottom - b.bottom).abs() < tolerance;
  }

  @override
  Rect? get currentBounds => _lastReportedBounds;

  @override
  OcclusionType get currentType => _type;

  @override
  double get devicePixelRatio => _getDevicePixelRatio();

  @override
  int get viewId => _getViewId();

  @override
  int get stableId => _stableId;

  @override
  bool get hasValidBounds => attached && hasSize;

  @override
  Rect? getUnionOfHistoricalBounds() {
    if (_timestampedBounds.isEmpty) {
      return _lastReportedBounds;
    }

    Rect? union;
    for (final entry in _timestampedBounds) {
      if (entry.bounds.width > 0 && entry.bounds.height > 0) {
        if (union == null) {
          union = entry.bounds;
        } else {
          union = union.expandToInclude(entry.bounds);
        }
      }
    }

    return union ?? _lastReportedBounds;
  }

  void _addToSlidingWindow(Rect bounds) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _timestampedBounds.add(TimestampedBounds(now, bounds));

    final cutoff = now - _boundsWindowMs;
    _timestampedBounds.removeWhere((entry) => entry.timestampMs < cutoff);
  }

  @override
  void recalculateBounds() {
    if (!attached || !hasSize) return;
    _calculateAndReportBounds();
  }

  @override
  void updateBoundsFromTransform() {
    if (!attached || !hasSize) return;
    if (!_shouldReport) return;

    final transform = getTransformTo(null);
    final rawBounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    final effectiveClip = _calculateEffectiveClip();
    Rect? finalBounds;

    if (effectiveClip != null) {
      final intersection = rawBounds.intersect(effectiveClip);

      final rawArea = rawBounds.width * rawBounds.height;
      final clippedArea = intersection.width > 0 && intersection.height > 0
          ? intersection.width * intersection.height
          : 0.0;
      final visibleRatio = rawArea > 0 ? clippedArea / rawArea : 0.0;

      if (clippedArea <= 0) {
        return;
      } else if (visibleRatio < 0.5) {
        finalBounds = rawBounds;
      } else {
        finalBounds = intersection;
      }
    } else {
      finalBounds = rawBounds;
    }

    final dpr = _getDevicePixelRatio();
    final snappedBounds = _snapToDevicePixels(finalBounds, dpr);

    _lastReportedBounds = snappedBounds;
    _addToSlidingWindow(snappedBounds);
  }
}
