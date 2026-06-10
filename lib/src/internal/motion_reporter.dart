import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'uxcam_internal_channel.dart';

class MotionReporter {
  MotionReporter._();

  static final MotionReporter instance = MotionReporter._();

  static const Duration _motionDecay = Duration(milliseconds: 300);

  bool _enabled = false;
  bool _motionActive = false;
  bool? _lastSentActive;

  Timer? _decayTimer;
  final Map<int, Offset> _pointerDownPositions = <int, Offset>{};
  bool _routeAttached = false;

  late final void Function(PointerEvent) _pointerHandler = _handlePointerEvent;

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) {
      _detachPointerRoute();
      _decayTimer?.cancel();
      _decayTimer = null;
      _pointerDownPositions.clear();
      _motionActive = false;
      if (_lastSentActive == true) _send(false);
      _lastSentActive = null;
      return;
    }
    _attachPointerRoute();
    _lastSentActive = false;
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

  void _handlePointerEvent(PointerEvent event) {
    if (!_enabled) return;

    if (event is PointerDownEvent) {
      _pointerDownPositions[event.pointer] = event.position;
    } else if (event is PointerMoveEvent) {
      final down = _pointerDownPositions[event.pointer];
      if (down != null && (event.position - down).distance > kTouchSlop) {
        _onMotionTick();
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerDownPositions.remove(event.pointer);
    } else if (event is PointerScrollEvent ||
        event is PointerPanZoomUpdateEvent) {
      _onMotionTick();
    }
  }

  void _onMotionTick() {
    _setMotionActive(true);
    _decayTimer?.cancel();
    _decayTimer = Timer(_motionDecay, () => _setMotionActive(false));
  }

  void _setMotionActive(bool active) {
    if (_motionActive == active) return;
    _motionActive = active;
    if (!_enabled || active == _lastSentActive) return;
    _send(active);
  }

  void _send(bool active) {
    _lastSentActive = active;
    UXCamInternal.send('motion', {'active': active});
  }

  @visibleForTesting
  void handlePointerEvent(PointerEvent event) => _handlePointerEvent(event);

  @visibleForTesting
  void debugReset() {
    _detachPointerRoute();
    _decayTimer?.cancel();
    _decayTimer = null;
    _pointerDownPositions.clear();
    _enabled = false;
    _motionActive = false;
    _lastSentActive = null;
  }

  @visibleForTesting
  bool get debugEnabled => _enabled;
}
