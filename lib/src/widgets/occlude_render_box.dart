import 'package:flutter/rendering.dart';
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
        registry.unregister(this);
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

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_enabled && !_isRegistered) {
      _isRegistered = true;
      registry.register(this);
    }
  }

  @override
  void detach() {
    if (_isRegistered) {
      _isRegistered = false;
      registry.unregister(this);
    }
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
  }

  bool _isEffectivelyInvisible() {
    RenderObject? current = this;
    while (current != null) {
      if (current is RenderOffstage && current.offstage) return true;
      if (current is RenderOpacity && current.opacity == 0) return true;
      if (current is RenderAnimatedOpacity && current.opacity.value == 0)
        return true;
      current = current.parent;
    }
    return false;
  }

  Rect? _calculateCurrentSnappedBounds() {
    if (!attached || !hasSize || !_enabled) return null;
    if (_isEffectivelyInvisible()) return null;

    final transform = getTransformTo(null);
    Rect bounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    final effectiveClip = _calculateEffectiveClip();
    if (effectiveClip != null) {
      bounds = bounds.intersect(effectiveClip);
    }

    if (bounds.width <= 0 || bounds.height <= 0) return null;

    final devicePixelRatio = _getDevicePixelRatio();
    return _snapToDevicePixels(bounds, devicePixelRatio);
  }

  Rect? _calculateEffectiveClip() {
    Rect? accumulatedClip;
    RenderObject? child = this;
    RenderObject? ancestor = parent;

    while (ancestor != null) {
      if (ancestor is RenderBox) {
        final clip = ancestor.describeApproximatePaintClip(child!);
        if (clip != null) {
          final transform = ancestor.getTransformTo(null);
          final globalClip = MatrixUtils.transformRect(transform, clip);
          accumulatedClip =
              accumulatedClip?.intersect(globalClip) ?? globalClip;
        }
      }
      child = ancestor;
      ancestor = ancestor.parent;
    }

    return accumulatedClip;
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
  int get stableId => _stableId;

  @override
  bool get hasValidBounds => attached && hasSize;

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

    if (_lastReportedBounds != null) {
      union = union == null
          ? _lastReportedBounds
          : union.expandToInclude(_lastReportedBounds!);
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _pruneSlidingWindow(nowMs);

    final snappedBounds = _calculateCurrentSnappedBounds();
    _lastReportedBounds = snappedBounds;

    if (snappedBounds != null) {
      _addToSlidingWindow(snappedBounds, nowMs);
    }
  }
}
