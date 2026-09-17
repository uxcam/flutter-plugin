import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_geometry.dart';
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

  int? _stableId;
  static int _idCounter = 0;
  static int _generateStableId() {
    return Object.hash(++_idCounter, DateTime.now().microsecondsSinceEpoch);
  }

  BuildContext? _context;
  Rect? _lastReportedBounds;
  bool _enabled;
  OcclusionType _type;
  bool _isRegistered = false;

  static const int _boundsWindowMs = 100;
  // Snapshot-based transitions can temporarily detach layers while a snapshot
  // is animated. Keep the last bounds briefly to avoid flicker.
  static const int _layerDetachGraceMs = 500;
  final _timestampedBounds = <TimestampedBounds>[];
  int? _layerDetachedSinceMs;

  // Repaint boundary provides a layer for opacity-based visibility checks.
  @override
  bool get isRepaintBoundary => true;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (_enabled) {
      if (attached && !_isRegistered) {
        _isRegistered = true;
        registry.register(this);
      }
      updateBoundsFromTransform();
    } else {
      _lastReportedBounds = null;
      _timestampedBounds.clear();
      if (_isRegistered) {
        _isRegistered = false;
        registry.remove(this);
      }
    }
    markNeedsPaint();
  }

  OcclusionType get type => _type;
  set type(OcclusionType value) {
    if (_type == value) return;
    _type = value;
    markNeedsPaint();
  }

  void updateContext(BuildContext context) {
    _context = context;
  }

  int _deriveStableId() {
    if (_context != null) {
      final element = _context as Element;
      final key = element.widget.key;
      if (key != null) {
        return Object.hash('key', key);
      }
    }

    final parentData = this.parentData;
    if (parentData is SliverMultiBoxAdaptorParentData &&
        parentData.index != null) {
      final viewId = _getViewId();
      return Object.hash('sliver-index', parentData.index, viewId);
    }

    return _generateStableId();
  }

  void _ensureStableId() {
    _stableId ??= _deriveStableId();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _ensureStableId();
    if (_enabled && !_isRegistered) {
      _isRegistered = true;
      registry.register(this);
    }
  }

  @override
  void detach() {
    if (_isRegistered) {
      _isRegistered = false;
      registry.markDetached(this);
    }
    super.detach();
  }

  @override
  void dispose() {
    registry.remove(this);
    _isRegistered = false;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
  }

  @override
  void clearHistoricalBounds() {
    _timestampedBounds.clear();
    _lastReportedBounds = null;
  }

  /// Layer-level opacity is not visible from the render tree, so it stays a
  /// separate check alongside [resolveOcclusionGeometry]'s render-tree verdict.
  bool _isHiddenByLayerOpacity() {
    final ContainerLayer? rootLayer = layer;
    if (rootLayer == null || !rootLayer.attached) return false;

    Layer? current = rootLayer.parent;
    while (current != null) {
      if (current is OpacityLayer && (current.alpha ?? 255) == 0) {
        return true;
      }
      current = current.parent;
    }

    return false;
  }

  bool _isLayerDetached(int nowMs) {
    final ContainerLayer? rootLayer = layer;
    if (rootLayer == null || !rootLayer.attached) {
      _layerDetachedSinceMs ??= nowMs;
      return true;
    }
    _layerDetachedSinceMs = null;
    return false;
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

  @override
  Rect? get currentBounds => _lastReportedBounds;

  @override
  OcclusionType get currentType => _type;

  @override
  double get devicePixelRatio => _getDevicePixelRatio();

  @override
  int get viewId => _getViewId();

  @override
  int get stableId {
    _ensureStableId();
    return _stableId!;
  }

  @override
  Rect? getUnionOfHistoricalBounds() {
    _pruneSlidingWindow(DateTime.now().millisecondsSinceEpoch);

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

    return union;
  }

  void _pruneSlidingWindow(int nowMs) {
    final cutoff = nowMs - _boundsWindowMs;
    _timestampedBounds.removeWhere((entry) => entry.timestampMs < cutoff);
  }

  void _addToSlidingWindow(Rect bounds, int nowMs) {
    _timestampedBounds.add(TimestampedBounds(nowMs, bounds));
    _pruneSlidingWindow(nowMs);
  }

  @override
  void recalculateBounds() {
    if (!attached || !hasSize) return;
    updateBoundsFromTransform();
  }

  @override
  void updateBoundsFromTransform() {
    if (!attached || !hasSize) return;
    if (_context == null || !(_context as Element).mounted) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_isLayerDetached(nowMs)) {
      final detachedForMs = nowMs - (_layerDetachedSinceMs ?? nowMs);
      if (detachedForMs > _layerDetachGraceMs) {
        _timestampedBounds.clear();
        _lastReportedBounds = null;
      } else if (_lastReportedBounds != null) {
        _addToSlidingWindow(_lastReportedBounds!, nowMs);
      } else {
        final transform = getTransformTo(null);
        final rawBounds =
            MatrixUtils.transformRect(transform, Offset.zero & size);
        _lastReportedBounds = rawBounds;
        _addToSlidingWindow(rawBounds, nowMs);
      }
      return;
    }

    _pruneSlidingWindow(nowMs);

    // One traversal serves both the visibility gate and the bounds below. This
    // used to resolve the ancestor chain twice per frame — once via
    // `_isEffectivelyInvisible()` and again inside
    // `_calculateCurrentSnappedBounds(skipVisibilityCheck: true)`.
    final geometry = resolveOcclusionGeometry(this);
    if (!geometry.isVisible || _isHiddenByLayerOpacity()) {
      _timestampedBounds.clear();
      _lastReportedBounds = null;
      return;
    }

    final previousBounds = _lastReportedBounds;
    final snappedBounds = _snappedBoundsFromGeometry(geometry);
    if (snappedBounds != null) {
      _lastReportedBounds = snappedBounds;
      _addToSlidingWindow(snappedBounds, nowMs);
      return;
    }

    if (previousBounds != null) {
      _addToSlidingWindow(previousBounds, nowMs);
      return;
    }

    // Fully clipped away with no history: fall back to the unclipped rect so a
    // capture racing this frame still masks something rather than nothing. Reuses
    // the transform already resolved above.
    _addToSlidingWindow(
        MatrixUtils.transformRect(geometry.transform, Offset.zero & size),
        nowMs);
  }

  /// Applies clipping and device-pixel snapping to an already-resolved geometry.
  Rect? _snappedBoundsFromGeometry(OcclusionGeometry geometry) {
    Rect bounds =
        MatrixUtils.transformRect(geometry.transform, Offset.zero & size);

    final effectiveClip = geometry.clip;
    if (effectiveClip != null) {
      bounds = bounds.intersect(effectiveClip);
    }

    if (bounds.width <= 0 || bounds.height <= 0) return null;

    return _snapToDevicePixels(bounds, _getDevicePixelRatio());
  }
}
