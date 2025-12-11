import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_models.dart';
import 'occlusion_registry.dart';

class OccludeRenderBox extends RenderProxyBox
    implements OcclusionReportingRenderBox, ScrollSubscriber {
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

  ScrollPosition? _trackedScrollPosition;
  bool _isScrolling = false;
  bool _visibilityCheckScheduled = false;
  bool _boundsUpdateScheduled = false;

  double _lastKnownVelocity = 0.0;
  double _lastScrollPixels = 0.0;
  int _lastScrollTimestamp = 0;

  ModalRoute<dynamic>? _trackedRoute;

  bool _isWidgetVisible = true;
  bool _isInViewport = true;
  bool _isRouteVisible = true;

  bool get _isCurrentlyVisible =>
      _isWidgetVisible && _isInViewport && _isRouteVisible;

  void _updateOcclusionState() {
    if (!attached) return;

    final shouldReport = _isCurrentlyVisible && _enabled;

    if (!shouldReport && _lastReportedBounds != null) {
      _lastReportedBounds = null;
      registry.markDirty(this);
    } else if (shouldReport && _lastReportedBounds == null) {
      _scheduleBoundsUpdate();
    }
  }

  void _scheduleBoundsUpdate() {
    if (_boundsUpdateScheduled || !attached) return;
    _boundsUpdateScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _boundsUpdateScheduled = false;
      if (attached && hasSize) {
        _calculateAndReportBounds();
      }
    });
  }

  void _updateWidgetVisibility(BuildContext context) {
    _isWidgetVisible = Visibility.of(context);
    _updateOcclusionState();
  }

  void _updateViewportVisibility() {
    if (!attached || !hasSize) return;

    final viewport = RenderAbstractViewport.maybeOf(this);
    if (viewport == null) {
      if (!_isInViewport) {
        _isInViewport = true;
        _updateOcclusionState();
      }
      return;
    }

    final globalBounds = localToGlobal(Offset.zero) & size;
    final viewportBox = viewport as RenderBox;
    final viewportBounds = viewportBox.localToGlobal(Offset.zero) & viewportBox.size;

    final wasInViewport = _isInViewport;
    _isInViewport = globalBounds.overlaps(viewportBounds);

    if (wasInViewport != _isInViewport) {
      _updateOcclusionState();
    }
  }

  void _updateRouteVisibility(bool visible) {
    if (_isRouteVisible == visible) return;
    _isRouteVisible = visible;
    _updateOcclusionState();
  }

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _updateOcclusionState();
    if (_enabled) markNeedsPaint();
  }

  OcclusionType get type => _type;
  set type(OcclusionType value) {
    if (_type == value) return;
    _type = value;
    if (_lastReportedBounds != null) {
      registry.markDirty(this);
    }
    markNeedsPaint();
  }

  void updateContext(BuildContext context) {
    _context = context;
    _updateWidgetVisibility(context);
    _setupScrollListener(context);
    _setupRouteListener(context);
  }

  void _setupScrollListener(BuildContext context) {
    _detachFromScrollable();

    final scrollable = _findActiveScrollable(context);

    if (scrollable != null) {
      _trackedScrollPosition = scrollable.position;
      registry.subscribeToScroll(_trackedScrollPosition!, this);
    } else {
      _isInViewport = true;
    }
  }

  ScrollableState? _findActiveScrollable(BuildContext context) {
    ScrollableState? result;
    context.visitAncestorElements((element) {
      if (element.widget is Scrollable) {
        final state = (element as StatefulElement).state;
        if (state is ScrollableState) {
          final physics = state.position.physics;
          if (physics is! NeverScrollableScrollPhysics) {
            result = state;
            return false;
          }
        }
      }
      return true;
    });
    return result;
  }

  void _detachFromScrollable() {
    if (_trackedScrollPosition != null) {
      registry.unsubscribeFromScroll(_trackedScrollPosition!, this);
      _trackedScrollPosition = null;
    }
  }

  @override
  void onScrollStateChanged(bool isScrolling) {
    final wasScrolling = _isScrolling;
    _isScrolling = isScrolling;

    if (wasScrolling && !_isScrolling) {
      _lastKnownVelocity = 0.0;
      _lastScrollTimestamp = 0;
      _scheduleBoundsUpdate();
      registry.signalMotionEnded();
    }
  }

  @override
  void onScrollPositionChanged() {
    if (!attached) return;

    _updateVelocityFromScrollPosition();

    if (!_visibilityCheckScheduled) {
      _visibilityCheckScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _visibilityCheckScheduled = false;
        _updateViewportVisibility();
      });
    }

    _scheduleBoundsUpdate();
  }

  void _updateVelocityFromScrollPosition() {
    final position = _trackedScrollPosition;
    if (position == null) {
      _lastKnownVelocity = 0.0;
      return;
    }

    final currentPixels = position.pixels;
    final currentTimestamp = DateTime.now().microsecondsSinceEpoch;

    if (_lastScrollTimestamp > 0) {
      final timeDeltaMicros = currentTimestamp - _lastScrollTimestamp;
      if (timeDeltaMicros > 0) {
        final pixelsDelta = currentPixels - _lastScrollPixels;
        _lastKnownVelocity = (pixelsDelta / timeDeltaMicros) * 1000000;
      }
    }

    _lastScrollPixels = currentPixels;
    _lastScrollTimestamp = currentTimestamp;
  }

  void _setupRouteListener(BuildContext context) {
    _detachFromRoute();

    final route = ModalRoute.of(context);
    if (route != null) {
      _trackedRoute = route;
      route.animation?.addListener(_onRouteAnimationTick);
      route.animation?.addStatusListener(_onPrimaryAnimationStatus);
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
    _trackedRoute?.animation?.removeStatusListener(_onPrimaryAnimationStatus);
    _trackedRoute?.secondaryAnimation?.removeListener(_onRouteAnimationTick);
    _trackedRoute?.secondaryAnimation
        ?.removeStatusListener(_onSecondaryAnimationStatus);
    _trackedRoute = null;
  }

  void _onRouteAnimationTick() {
    if (!attached) return;
    markNeedsPaint();
  }

  void _onPrimaryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      registry.signalMotionEnded();
    } else if (status == AnimationStatus.dismissed) {
      registry.signalMotionEnded();
    }
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _checkIfCoveredByOpaqueRoute();
      registry.signalMotionEnded();
    } else if (status == AnimationStatus.reverse) {
      _updateRouteVisibility(true);
      markNeedsPaint();
    } else if (status == AnimationStatus.dismissed) {
      _updateRouteVisibility(true);
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (attached && _isRouteVisible) {
          markNeedsPaint();
          registry.signalMotionEnded();
        }
      });
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

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    registry.register(this);
  }

  @override
  void detach() {
    _detachFromScrollable();
    _detachFromRoute();
    registry.unregister(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _calculateAndReportBounds();
  }

  void _calculateAndReportBounds() {
    if (!_enabled || !attached || !_isCurrentlyVisible) {
      if (_lastReportedBounds != null) {
        _lastReportedBounds = null;
        registry.markDirty(this);
      }
      return;
    }

    final transform = getTransformTo(null);
    final rawBounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    final effectiveClip = _calculateEffectiveClip();

    Rect? clippedBounds;
    if (effectiveClip != null) {
      final intersection = rawBounds.intersect(effectiveClip);
      if (intersection.width > 0 && intersection.height > 0) {
        clippedBounds = intersection;
      }
    } else {
      clippedBounds = rawBounds;
    }

    final devicePixelRatio = _getDevicePixelRatio();
    Rect? snappedBounds = clippedBounds != null
        ? _snapToDevicePixels(clippedBounds, devicePixelRatio)
        : null;

    snappedBounds = _applyVelocityExpansion(snappedBounds, effectiveClip);

    if (!_rectsEqualWithinTolerance(_lastReportedBounds, snappedBounds)) {
      _lastReportedBounds = snappedBounds;
      registry.markDirty(this);
    }
  }

  Rect? _applyVelocityExpansion(Rect? bounds, Rect? effectiveClip) {
    if (bounds == null) return null;

    if (!_isScrolling || _lastKnownVelocity.abs() < 100) {
      return bounds;
    }

    const captureLatencySeconds = 0.05;

    final expansionPixels =
        (_lastKnownVelocity.abs() * captureLatencySeconds).clamp(0.0, 80.0);

    Rect expandedBounds;

    if (_lastKnownVelocity < 0) {
      expandedBounds = Rect.fromLTRB(
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom + expansionPixels,
      );
    } else {
      expandedBounds = Rect.fromLTRB(
        bounds.left,
        bounds.top - expansionPixels,
        bounds.right,
        bounds.bottom,
      );
    }

    if (effectiveClip != null) {
      final intersection = expandedBounds.intersect(effectiveClip);
      if (intersection.width > 0 && intersection.height > 0) {
        return intersection;
      }
      return bounds;
    }

    return expandedBounds;
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
  void recalculateBounds() {
    if (!attached || !hasSize) return;
    _calculateAndReportBounds();
  }
}
