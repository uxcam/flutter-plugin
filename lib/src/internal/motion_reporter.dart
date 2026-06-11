import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'uxcam_internal_channel.dart';

class MotionReporter {
  MotionReporter._();

  static final MotionReporter instance = MotionReporter._();

  static const Duration _recordingRequestIdleTimeout = Duration(seconds: 2);
  static const Duration _discreteScrollActiveWindow =
      Duration(milliseconds: 100);

  bool _recordingRequested = false;
  bool _panZoomActive = false;
  bool? _lastSentActive;

  Timer? _recordingIdleTimer;
  final Map<int, Offset> _pointerDownPositions = <int, Offset>{};
  final Set<int> _scrollingPointers = <int>{};
  int? _lastDiscreteScrollMs;
  bool _routeAttached = false;

  late final void Function(PointerEvent) _pointerHandler = _handlePointerEvent;

  void markRecordingRequested() {
    if (!_recordingRequested) {
      _recordingRequested = true;
      _attachPointerRoute();
    }

    _sendIfChanged(_currentMotionActive);
    _recordingIdleTimer?.cancel();
    _recordingIdleTimer =
        Timer(_recordingRequestIdleTimeout, _clearRecordingRequest);
  }

  void _attachPointerRoute() {
    if (_routeAttached) return;
    try {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_pointerHandler);
      _routeAttached = true;
    } catch (_) {}
  }

  void _detachPointerRoute() {
    if (!_routeAttached) return;
    try {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointerHandler);
    } catch (_) {}
    _routeAttached = false;
  }

  void _clearRecordingRequest() {
    _recordingRequested = false;
    _detachPointerRoute();
    _recordingIdleTimer?.cancel();
    _recordingIdleTimer = null;
    _pointerDownPositions.clear();
    _scrollingPointers.clear();
    _panZoomActive = false;
    _lastDiscreteScrollMs = null;
    if (_lastSentActive == true) {
      _send(false);
    }
    _lastSentActive = null;
  }

  void _handlePointerEvent(PointerEvent event) {
    if (!_recordingRequested) return;

    if (event is PointerDownEvent) {
      _pointerDownPositions[event.pointer] = event.position;
    } else if (event is PointerMoveEvent) {
      final down = _pointerDownPositions[event.pointer];
      if (down != null && (event.position - down).distance > kTouchSlop) {
        _scrollingPointers.add(event.pointer);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerDownPositions.remove(event.pointer);
      _scrollingPointers.remove(event.pointer);
    } else if (event is PointerPanZoomStartEvent ||
        event is PointerPanZoomUpdateEvent) {
      _panZoomActive = true;
    } else if (event is PointerPanZoomEndEvent) {
      _panZoomActive = false;
    } else if (event is PointerScrollEvent) {
      _lastDiscreteScrollMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  bool get _currentMotionActive {
    if (_scrollingPointers.isNotEmpty || _panZoomActive) {
      return true;
    }
    final lastDiscreteScrollMs = _lastDiscreteScrollMs;
    if (lastDiscreteScrollMs == null) {
      return false;
    }
    final elapsedMs =
        DateTime.now().millisecondsSinceEpoch - lastDiscreteScrollMs;
    return elapsedMs <= _discreteScrollActiveWindow.inMilliseconds;
  }

  void _send(bool active) {
    _lastSentActive = active;
    UXCamInternal.send('motion', {'active': active});
  }

  void _sendIfChanged(bool active) {
    if (_lastSentActive == active) return;
    _send(active);
  }

  @visibleForTesting
  void handlePointerEvent(PointerEvent event) => _handlePointerEvent(event);

  @visibleForTesting
  void debugReset() {
    _detachPointerRoute();
    _recordingIdleTimer?.cancel();
    _recordingIdleTimer = null;
    _pointerDownPositions.clear();
    _scrollingPointers.clear();
    _recordingRequested = false;
    _panZoomActive = false;
    _lastDiscreteScrollMs = null;
    _lastSentActive = null;
  }

  @visibleForTesting
  bool get debugEnabled => _recordingRequested;
}
