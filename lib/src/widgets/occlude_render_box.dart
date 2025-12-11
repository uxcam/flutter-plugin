import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
  bool _visibilityCheckScheduled = false;
  bool _boundsUpdateScheduled = false;

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
      _trackedScrollPosition!.isScrollingNotifier
          .addListener(_onScrollStateChanged);
      _trackedScrollPosition!.addListener(_onScrollPositionChanged);
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
    _trackedScrollPosition?.removeListener(_onScrollPositionChanged);
    _trackedScrollPosition?.isScrollingNotifier
        .removeListener(_onScrollStateChanged);
    _trackedScrollPosition = null;
  }

  void _onScrollStateChanged() {
    final wasScrolling = _isScrolling;
    _isScrolling = _trackedScrollPosition?.isScrollingNotifier.value ?? false;

    if (wasScrolling && !_isScrolling) {
      _scheduleBoundsUpdate();
    }
  }

  void _onScrollPositionChanged() {
    if (!attached) return;

    if (!_visibilityCheckScheduled) {
      _visibilityCheckScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _visibilityCheckScheduled = false;
        _updateViewportVisibility();
      });
    }

    _scheduleBoundsUpdate();
  }

  void _setupRouteListener(BuildContext context) {
    _detachFromRoute();

    final route = ModalRoute.of(context);
    if (route != null) {
      _trackedRoute = route;
      route.secondaryAnimation?.addStatusListener(_onSecondaryAnimationStatus);
      _updateRouteVisibility(route.isCurrent);
    } else {
      _updateRouteVisibility(true);
    }
  }

  void _detachFromRoute() {
    _trackedRoute?.secondaryAnimation
        ?.removeStatusListener(_onSecondaryAnimationStatus);
    _trackedRoute = null;
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _updateRouteVisibility(false);
    } else if (status == AnimationStatus.dismissed) {
      _updateRouteVisibility(true);
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (attached && _isRouteVisible) {
          markNeedsPaint();
        }
      });
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

    _scheduleBoundsUpdate();
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
    final snappedBounds = clippedBounds != null
        ? _snapToDevicePixels(clippedBounds, devicePixelRatio)
        : null;

    if (!_rectsEqualWithinTolerance(_lastReportedBounds, snappedBounds)) {
      _lastReportedBounds = snappedBounds;
      registry.markDirty(this);
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
}
