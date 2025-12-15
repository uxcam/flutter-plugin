import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_models.dart';
import 'occlusion_registry.dart';

typedef VisibilityChecker = bool Function(
    RenderObject ancestor, RenderObject child);

final Map<Type, VisibilityChecker> _visibilityCheckers = {
  RenderIndexedStack: _checkIndexedStackVisibility,
  RenderViewport: _checkViewportVisibility,
};

bool _checkIndexedStackVisibility(RenderObject ancestor, RenderObject child) {
  final indexedStack = ancestor as RenderIndexedStack;
  final displayedIndex = indexedStack.index;
  if (displayedIndex == null) return false;

  int childIndex = 0;
  RenderBox? current = indexedStack.firstChild;
  while (current != null) {
    if (current == child) {
      return childIndex == displayedIndex;
    }
    childIndex++;
    current = indexedStack.childAfter(current);
  }
  return false;
}

bool _checkViewportVisibility(RenderObject ancestor, RenderObject child) {
  final viewport = ancestor as RenderViewport;

  RenderSliver? sliver;
  RenderObject? current = child;
  while (current != null && current != viewport) {
    if (current is RenderSliver) {
      sliver = current;
      break;
    }
    current = current.parent;
  }

  if (sliver == null) return true;

  final geometry = sliver.geometry;
  if (geometry == null || !geometry.visible) return false;

  return geometry.paintExtent > 0;
}

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

  static const int _boundsWindowMs = 100;
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
    RenderObject? child = this;
    RenderObject? ancestor = parent;

    while (ancestor != null) {
      if (!ancestor.paintsChild(child!)) {
        return true;
      }

      final checker = _visibilityCheckers[ancestor.runtimeType];
      if (checker != null && !checker(ancestor, child)) {
        return true;
      }

      child = ancestor;
      ancestor = ancestor.parent;
    }
    return false;
  }

  Rect? _calculateCurrentSnappedBounds({bool skipVisibilityCheck = false}) {
    if (!attached || !hasSize || !_enabled) return null;
    if (!skipVisibilityCheck && _isEffectivelyInvisible()) return null;

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
    _pruneSlidingWindow(nowMs);

    if (_isEffectivelyInvisible()) {
      _timestampedBounds.clear();
      _lastReportedBounds = null;
      return;
    }

    final snappedBounds = _calculateCurrentSnappedBounds(skipVisibilityCheck: true);
    _lastReportedBounds = snappedBounds;

    if (snappedBounds != null) {
      _addToSlidingWindow(snappedBounds, nowMs);
    }
  }
}
