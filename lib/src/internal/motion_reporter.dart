import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'uxcam_internal_channel.dart';

class MotionReporter {
  MotionReporter._();

  static final MotionReporter instance = MotionReporter._();

  static const Duration _recordingRequestIdleTimeout = Duration(seconds: 5);
  static const Duration _discreteScrollActiveWindow =
      Duration(milliseconds: 100);

  static const Duration _ballisticMaxDuration = Duration(milliseconds: 2000);

  bool _recordingRequested = false;
  bool _panZoomActive = false;
  bool _ballisticActive = false;
  bool? _lastSentActive;

  Timer? _recordingIdleTimer;
  Timer? _discreteScrollTimer;
  Timer? _ballisticFallbackTimer;
  int _ballisticDeadlineMs = 0;
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
    _armIdleTimer();
  }

  void stop() => _clearRecordingRequest();

  void _armIdleTimer() {
    _recordingIdleTimer?.cancel();
    _recordingIdleTimer = Timer(_recordingRequestIdleTimeout, _onIdleTimeout);
  }

  void _onIdleTimeout() {
    if (_currentMotionActive) {
      _armIdleTimer();
      return;
    }
    _clearRecordingRequest();
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
    _discreteScrollTimer?.cancel();
    _discreteScrollTimer = null;
    _endBallistic(notify: false);
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
      _endBallistic(notify: false);
      _pointerDownPositions[event.pointer] = event.position;
    } else if (event is PointerMoveEvent) {
      final down = _pointerDownPositions[event.pointer];
      if (down != null && (event.position - down).distance > kTouchSlop) {
        _scrollingPointers.add(event.pointer);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final wasScrolling = _scrollingPointers.remove(event.pointer);
      _pointerDownPositions.remove(event.pointer);
      if (wasScrolling && event is PointerUpEvent) {
        _beginBallistic();
      }
    } else if (event is PointerPanZoomStartEvent ||
        event is PointerPanZoomUpdateEvent) {
      _panZoomActive = true;
    } else if (event is PointerPanZoomEndEvent) {
      _panZoomActive = false;
      _beginBallistic();
    } else if (event is PointerScrollEvent) {
      _lastDiscreteScrollMs = DateTime.now().millisecondsSinceEpoch;
      _discreteScrollTimer?.cancel();
      _discreteScrollTimer = Timer(
        _discreteScrollActiveWindow + const Duration(milliseconds: 10),
        () => _sendIfChanged(_currentMotionActive),
      );
    }

    _sendIfChanged(_currentMotionActive);
  }

  void _beginBallistic() {
    _ballisticDeadlineMs = DateTime.now().millisecondsSinceEpoch +
        _ballisticMaxDuration.inMilliseconds;
    if (_ballisticActive) return;
    _ballisticActive = true;
    _ballisticFallbackTimer?.cancel();
    _ballisticFallbackTimer = Timer(_ballisticMaxDuration, _endBallistic);
    try {
      SchedulerBinding.instance.addPostFrameCallback(_onBallisticFrame);
    } catch (_) {}
  }

  void _onBallisticFrame(Duration _) {
    if (!_ballisticActive) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= _ballisticDeadlineMs ||
        !SchedulerBinding.instance.hasScheduledFrame) {
      _endBallistic();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback(_onBallisticFrame);
  }

  void _endBallistic({bool notify = true}) {
    _ballisticFallbackTimer?.cancel();
    _ballisticFallbackTimer = null;
    if (!_ballisticActive) return;
    _ballisticActive = false;
    if (notify) {
      _sendIfChanged(_currentMotionActive);
    }
  }

  bool get _currentMotionActive {
    if (_scrollingPointers.isNotEmpty || _panZoomActive || _ballisticActive) {
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
    _discreteScrollTimer?.cancel();
    _discreteScrollTimer = null;
    _ballisticFallbackTimer?.cancel();
    _ballisticFallbackTimer = null;
    _ballisticActive = false;
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
