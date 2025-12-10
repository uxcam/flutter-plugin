import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_models.dart';
import 'occlusion_registry.dart';

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

  ScrollPosition? _trackedScrollPosition;
  bool _isScrolling = false;

  // Route visibility tracking
  ModalRoute<dynamic>? _trackedRoute;
  bool _isRouteVisible = true;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _markOcclusionDirty();
    markNeedsPaint();
  }

  OcclusionType get type => _type;
  set type(OcclusionType value) {
    if (_type == value) return;
    _type = value;
    _markOcclusionDirty();
    markNeedsPaint();
  }

  void _markOcclusionDirty() {
    if (!attached) return;

    if (!_enabled && _lastReportedBounds != null) {
      _lastReportedBounds = null;
      registry.markDirty(this);
    } else if (_enabled) {
      registry.markDirty(this);
    }
  }

  void updateContext(BuildContext context) {
    _context = context;
    _setupScrollListener(context);
    _setupRouteListener(context);
  }

  void _setupScrollListener(BuildContext context) {
    _detachFromScrollable();

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _trackedScrollPosition = scrollable.position;
      _trackedScrollPosition!.isScrollingNotifier
          .addListener(_onScrollStateChanged);
    }
  }

  void _detachFromScrollable() {
    _trackedScrollPosition?.isScrollingNotifier
        .removeListener(_onScrollStateChanged);
    _trackedScrollPosition = null;
  }

  void _onScrollStateChanged() {
    final wasScrolling = _isScrolling;
    _isScrolling = _trackedScrollPosition?.isScrollingNotifier.value ?? false;

    if (wasScrolling && !_isScrolling) {
      markNeedsPaint();
    }
  }


  void _setupRouteListener(BuildContext context) {
    _detachFromRoute();

    final route = ModalRoute.of(context);
    if (route != null) {
      _trackedRoute = route;
      route.secondaryAnimation?.addStatusListener(_onSecondaryAnimationStatus);
      _setRouteVisible(route.isCurrent);
    } else {
      _setRouteVisible(true);
    }
  }

  void _detachFromRoute() {
    _trackedRoute?.secondaryAnimation
        ?.removeStatusListener(_onSecondaryAnimationStatus);
    _trackedRoute = null;
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _setRouteVisible(false);
    } else if (status == AnimationStatus.dismissed) {
      _setRouteVisible(true);
    }
  }

  void _setRouteVisible(bool visible) {
    if (_isRouteVisible == visible) return;
    _isRouteVisible = visible;

    if (!visible && _lastReportedBounds != null) {
      _lastReportedBounds = null;
      registry.markDirty(this);
    } else if (visible) {
      markNeedsPaint();
    }
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

    if (_isScrolling) {
      _calculateAndReportBoundsThrottled(threshold: 50.0);
    } else {
      _calculateAndReportBounds();
    }
  }

  void _calculateAndReportBounds() {
    if (!_enabled || !attached || !_isRouteVisible) {
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
    final snappedBounds = clippedBounds != null
        ? _snapToDevicePixels(clippedBounds, devicePixelRatio)
        : null;

    if (!_rectsEqualWithinTolerance(_lastReportedBounds, snappedBounds)) {
      _lastReportedBounds = snappedBounds;
      registry.markDirty(this);
    }
  }

  void _calculateAndReportBoundsThrottled({required double threshold}) {
    if (!_enabled || !attached || !_isRouteVisible) {
      if (_lastReportedBounds != null) {
        _lastReportedBounds = null;
        registry.markDirty(this);
      }
      return;
    }

    final transform = getTransformTo(null);
    final rawBounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    if (_lastReportedBounds == null ||
        !_rectsWithinThreshold(_lastReportedBounds!, rawBounds, threshold)) {
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

      if (clippedBounds != null) {
        final dpr = _getDevicePixelRatio();
        _lastReportedBounds = _snapToDevicePixels(clippedBounds, dpr);
        registry.markDirty(this);
      }
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

  bool _rectsWithinThreshold(Rect a, Rect b, double threshold) {
    return (a.left - b.left).abs() < threshold &&
        (a.top - b.top).abs() < threshold;
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
}
