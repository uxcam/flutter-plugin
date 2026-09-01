import 'dart:async';

import 'package:flutter/scheduler.dart';

import 'uxcam_internal_channel.dart';

class RenderActivityReporter {
  RenderActivityReporter._();

  static final RenderActivityReporter instance = RenderActivityReporter._();

  static const Duration _quiescenceThreshold = Duration(milliseconds: 700);

  bool _started = false;
  bool _callbackRegistered = false;
  bool _active = false;
  int _lastFrameMs = 0;
  Timer? _quiescenceTimer;

  void start() {
    if (_started) return;
    _started = true;
    if (_callbackRegistered) return;
    try {
      SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
      _callbackRegistered = true;
    } catch (_) {
      _started = false;
    }
  }

  void stop() {
    _started = false;
    _quiescenceTimer?.cancel();
    _quiescenceTimer = null;
    if (_active) {
      UXCamInternal.send('renderActivity', {'active': false});
    }
    _active = false;
  }

  void _onFrame(Duration _) {
    if (!_started) return;
    _lastFrameMs = DateTime.now().millisecondsSinceEpoch;
    if (!_active) {
      _active = true;
      UXCamInternal.send('renderActivity', {'active': true});
    }

    _quiescenceTimer ??= Timer(_quiescenceThreshold, _checkQuiescence);
  }

  void _checkQuiescence() {
    _quiescenceTimer = null;
    if (!_started) return;
    final idleMs = DateTime.now().millisecondsSinceEpoch - _lastFrameMs;
    final thresholdMs = _quiescenceThreshold.inMilliseconds;
    if (idleMs >= thresholdMs - 50) {
      if (_active) {
        _active = false;
        UXCamInternal.send('renderActivity', {'active': false});
      }
      return;
    }
    _quiescenceTimer =
        Timer(Duration(milliseconds: thresholdMs - idleMs), _checkQuiescence);
  }
}
