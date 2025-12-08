import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef TapCallback = void Function(Offset position, Set<int> hitTargetHashes);

/// Global pointer event interceptor via GestureBinding.pointerRouter.
class UXCamGestureInterceptor {
  // Use eager singleton to prevent resurrection issues
  static final UXCamGestureInterceptor _instance = UXCamGestureInterceptor._internal();
  factory UXCamGestureInterceptor() => _instance;
  UXCamGestureInterceptor._internal();

  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _isHandlerRegistered = false;
  DateTime? _lastTapTime;

  static const _debounceMs = 50;

  TapCallback? onTap;

  // Store bound handler reference to ensure proper removal
  late final void Function(PointerEvent) _boundHandler = _handlePointerEvent;

  void initialize({TapCallback? onTap}) {
    if (!_isMainIsolate()) {
      assert(false, 'UXCam must be initialized on the main UI isolate');
      return;
    }

    if (_isInitialized) {
      if (onTap != null) this.onTap = onTap;
      return;
    }
    _isInitialized = true;
    this.onTap = onTap;

    // Always remove existing handler first using stored reference
    if (_isHandlerRegistered) {
      try {
        GestureBinding.instance.pointerRouter.removeGlobalRoute(_boundHandler);
      } catch (_) {}
      _isHandlerRegistered = false;
    }

    GestureBinding.instance.pointerRouter.addGlobalRoute(_boundHandler);
    _isHandlerRegistered = true;
  }

  void dispose() {
    if (!_isInitialized) return;

    if (_isHandlerRegistered) {
      try {
        GestureBinding.instance.pointerRouter.removeGlobalRoute(_boundHandler);
      } catch (_) {}
      _isHandlerRegistered = false;
    }

    _isInitialized = false;
    // Don't null out _instance - eager singleton prevents resurrection
  }

  bool _isMainIsolate() {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  void enable() {
    _isEnabled = true;
  }

  void disable() {
    _isEnabled = false;
  }

  bool get isEnabled => _isEnabled;

  bool get isInitialized => _isInitialized;

  void _handlePointerEvent(PointerEvent event) {
    if (!_isEnabled) return;
    if (event is! PointerDownEvent) return;
    if (_isScrollOrWheelEvent(event)) return;

    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _debounceMs) {
      return;
    }
    _lastTapTime = now;

    final hitResult = _performHitTest(event.position, event.viewId);
    final hitTargetSet = _buildTargetSet(hitResult);

    if (hitTargetSet.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyAndProcess(event.position, event.viewId);
      });
      return;
    }

    onTap?.call(event.position, hitTargetSet);
  }

  void _verifyAndProcess(Offset position, int? viewId) {
    final hitResult = _performHitTest(position, viewId);
    final hitTargetSet = _buildTargetSet(hitResult);

    if (hitTargetSet.isNotEmpty) {
      onTap?.call(position, hitTargetSet);
    }
  }

  bool _isScrollOrWheelEvent(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.trackpad) return true;
    if (event.buttons == kMiddleMouseButton) return true;
    return false;
  }

  Set<int> _buildTargetSet(HitTestResult result) {
    final targetSet = <int>{};

    for (final entry in result.path) {
      RenderObject? renderBox;

      if (entry is BoxHitTestEntry) {
        renderBox = entry.target;
      } else {
        renderBox = _findNearestRenderBox(entry.target);
      }

      if (renderBox != null && renderBox is RenderBox) {
        targetSet.add(identityHashCode(renderBox));
      }
    }

    return targetSet;
  }

  RenderObject? _findNearestRenderBox(HitTestTarget target) {
    if (target is! RenderObject) return null;

    RenderObject? current = target;
    while (current != null) {
      if (current is RenderBox) return current;
      current = current.parent;
    }
    return null;
  }

  HitTestResult _performHitTest(Offset position, int? viewId) {
    final result = HitTestResult();

    if (viewId != null) {
      try {
        RendererBinding.instance.hitTestInView(result, position, viewId);
      } catch (_) {
        _hitTestFallback(result, position);
      }
    } else {
      _hitTestFallback(result, position);
    }

    return result;
  }

  void _hitTestFallback(HitTestResult result, Offset position) {
    try {
      final views = WidgetsBinding.instance.renderViews;
      if (views.isNotEmpty) {
        views.first.hitTest(result, position: position);
        return;
      }
    } catch (_) {}

    try {
      // ignore: deprecated_member_use
      RendererBinding.instance.renderView.hitTest(result, position: position);
    } catch (_) {}
  }
}
