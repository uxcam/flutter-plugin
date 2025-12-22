import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Types of gestures that can be detected
enum GestureType {
  tap,
  longPress,
  doubleTap,
  swipeLeft,
  swipeRight,
  swipeUp,
  swipeDown,
}

typedef TapCallback = void Function(Offset position, Set<int> hitTargetHashes);
typedef GestureCallback = void Function(
    GestureType type, Offset position, Set<int> hitTargetHashes);

/// Global pointer event interceptor via GestureBinding.pointerRouter.
/// Supports tap, long press, double tap, and swipe gestures.
class UXCamGestureInterceptor {
  // Use eager singleton to prevent resurrection issues
  static final UXCamGestureInterceptor _instance =
      UXCamGestureInterceptor._internal();
  factory UXCamGestureInterceptor() => _instance;
  UXCamGestureInterceptor._internal();

  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _isHandlerRegistered = false;

  // Gesture detection thresholds
  static const _debounceMs = 50;
  static const _longPressThresholdMs = 500;
  static const _doubleTapThresholdMs = 300;
  static const _swipeMinDistance = 50.0;
  static const _doubleTapMaxDistance = 30.0;

  // State for gesture detection
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  DateTime? _pointerDownTime;
  Offset? _pointerDownPosition;
  int? _activePointerId;
  Timer? _longPressTimer;
  Set<int>? _activeHitTargets;
  bool _tapFiredForCurrentPointer = false;

  TapCallback? onTap;
  GestureCallback? onGesture;

  // Store bound handler reference to ensure proper removal
  late final void Function(PointerEvent) _boundHandler = _handlePointerEvent;

  void initialize({TapCallback? onTap, GestureCallback? onGesture}) {
    if (!_isMainIsolate()) {
      assert(false, 'UXCam must be initialized on the main UI isolate');
      return;
    }

    if (_isInitialized) {
      if (onTap != null) this.onTap = onTap;
      if (onGesture != null) this.onGesture = onGesture;
      return;
    }
    _isInitialized = true;
    this.onTap = onTap;
    this.onGesture = onGesture;

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

    _cancelLongPressTimer();

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
    _cancelLongPressTimer();
  }

  bool get isEnabled => _isEnabled;

  bool get isInitialized => _isInitialized;

  void _handlePointerEvent(PointerEvent event) {
    if (!_isEnabled) return;

    if (event is PointerDownEvent) {
      _handlePointerDown(event);
    } else if (event is PointerUpEvent) {
      _handlePointerUp(event);
    } else if (event is PointerMoveEvent) {
      _handlePointerMove(event);
    } else if (event is PointerCancelEvent) {
      _handlePointerCancel(event);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isScrollOrWheelEvent(event)) return;

    // Debounce check
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _debounceMs) {
      return;
    }

    _activePointerId = event.pointer;
    _pointerDownTime = now;
    _pointerDownPosition = event.position;
    _tapFiredForCurrentPointer = false;

    final hitResult = _performHitTest(event.position, event.viewId);
    _activeHitTargets = _buildTargetSet(hitResult);

    if (_activeHitTargets!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retryResult = _performHitTest(event.position, event.viewId);
        final retryTargets = _buildTargetSet(retryResult);
        if (retryTargets.isNotEmpty && !_tapFiredForCurrentPointer) {
          _activeHitTargets = retryTargets;
          _fireTapImmediately(event.position, retryTargets);
        }
      });
      return;
    }

    // Fire tap IMMEDIATELY on pointer down (original behavior for trackData capture)
    _fireTapImmediately(event.position, _activeHitTargets!);

    // Start long press timer for additional gesture detection
    _startLongPressTimer(event.position);
  }

  /// Fire tap immediately on pointer down to capture widget state correctly.
  /// This is the original behavior that ensures uiValue extraction works.
  void _fireTapImmediately(Offset position, Set<int> hitTargets) {
    if (_tapFiredForCurrentPointer) return;
    _tapFiredForCurrentPointer = true;
    _lastTapTime = DateTime.now();
    _lastTapPosition = position;

    onTap?.call(position, hitTargets);
    onGesture?.call(GestureType.tap, position, hitTargets);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;

    _cancelLongPressTimer();

    final downPosition = _pointerDownPosition;
    final downTime = _pointerDownTime;
    final hitTargets = _activeHitTargets;

    if (downPosition == null || downTime == null || hitTargets == null || hitTargets.isEmpty) {
      _resetPointerState();
      return;
    }

    final upPosition = event.position;
    final duration = DateTime.now().difference(downTime);

    // Check for swipe gesture (only fire if significant movement)
    final distance = (upPosition - downPosition).distance;
    if (distance >= _swipeMinDistance && duration.inMilliseconds < 500) {
      final swipeType = _detectSwipeDirection(downPosition, upPosition);
      if (swipeType != null) {
        onGesture?.call(swipeType, downPosition, hitTargets);
      }
    }

    // Check for double tap
    if (_lastTapTime != null && _lastTapPosition != null) {
      final timeSinceLastTap = DateTime.now().difference(_lastTapTime!);
      final distanceFromLastTap = (downPosition - _lastTapPosition!).distance;

      if (timeSinceLastTap.inMilliseconds < _doubleTapThresholdMs &&
          distanceFromLastTap < _doubleTapMaxDistance) {
        onGesture?.call(GestureType.doubleTap, downPosition, hitTargets);
      }
    }

    _resetPointerState();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId) return;

    // Cancel long press if moved too far
    if (_pointerDownPosition != null) {
      final distance = (event.position - _pointerDownPosition!).distance;
      if (distance > _doubleTapMaxDistance) {
        _cancelLongPressTimer();
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _cancelLongPressTimer();
    _resetPointerState();
  }

  void _startLongPressTimer(Offset position) {
    _cancelLongPressTimer();
    _longPressTimer = Timer(
      const Duration(milliseconds: _longPressThresholdMs),
      () {
        if (_activeHitTargets != null && _activeHitTargets!.isNotEmpty) {
          onGesture?.call(GestureType.longPress, position, _activeHitTargets!);
        }
      },
    );
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _resetPointerState() {
    _activePointerId = null;
    _pointerDownTime = null;
    _pointerDownPosition = null;
    _activeHitTargets = null;
    _tapFiredForCurrentPointer = false;
  }

  GestureType? _detectSwipeDirection(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Determine primary direction
    if (dx.abs() > dy.abs()) {
      // Horizontal swipe
      return dx > 0 ? GestureType.swipeRight : GestureType.swipeLeft;
    } else {
      // Vertical swipe
      return dy > 0 ? GestureType.swipeDown : GestureType.swipeUp;
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
