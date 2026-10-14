import 'dart:async';
import 'dart:io';

import 'dart:ui' show FrameTiming, PlatformDispatcher, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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

  // View size changes (Android): the SDK holds native copies until a frame at
  // the new size is rasterized. Tracked from the first start() on, recording or
  // not, so the SDK's picture never goes stale between sessions.
  Size? _reportedSize;
  Size? _pendingSize;
  int _pendingFrame = -1;
  int _resizeSeq = 0;

  void start() {
    if (_started) return;
    _started = true;
    if (!kIsWeb && Platform.isAndroid) {
      // Say "drawing" now, since an earlier stop() left the SDK at "not
      // drawing"; report idle if no frame arrives within the threshold.
      _active = true;
      UXCamInternal.send('renderActivity', {'active': true});
      _lastFrameMs = DateTime.now().millisecondsSinceEpoch;
      _quiescenceTimer ??= Timer(_quiescenceThreshold, _checkQuiescence);
      _reportIdleSize();
    }
    if (_callbackRegistered) return;
    try {
      SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
      if (!kIsWeb && Platform.isAndroid) {
        SchedulerBinding.instance.addTimingsCallback(_onTimings);
      }
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
    if (!kIsWeb && Platform.isAndroid) _noteViewSize();
    if (!_started) return;
    _lastFrameMs = DateTime.now().millisecondsSinceEpoch;
    if (!_active) {
      _active = true;
      UXCamInternal.send('renderActivity', {'active': true});
    }

    _quiescenceTimer ??= Timer(_quiescenceThreshold, _checkQuiescence);
  }

  /// On an idle start, reports the current size as already drawn, so only a
  /// real size change holds the SDK's native copies. Once, and not while a
  /// frame is pending.
  void _reportIdleSize() {
    if (_reportedSize != null || _pendingSize != null) return;
    if (SchedulerBinding.instance.hasScheduledFrame) return;
    final views = RendererBinding.instance.renderViews;
    if (views.isEmpty) return;
    final size = views.first.flutterView.physicalSize;
    if (size.isEmpty) return;
    _reportedSize = size;
    _resizeSeq++;
    UXCamInternal.send('resizeLaidOut', {'seq': _resizeSeq});
    _sendPresented(size);
  }

  /// Runs after each frame is laid out: a frame at a size not yet reported is
  /// reported as laid out, and becomes pending until its raster timing arrives.
  void _noteViewSize() {
    final views = RendererBinding.instance.renderViews;
    if (views.isEmpty) return;
    final size = views.first.flutterView.physicalSize;
    if (size.isEmpty || size == (_pendingSize ?? _reportedSize)) return;
    _pendingSize = size;
    _pendingFrame = PlatformDispatcher.instance.frameData.frameNumber;
    _resizeSeq++;
    UXCamInternal.send('resizeLaidOut', {'seq': _resizeSeq});
  }

  /// Raster timings arrive after the frames are rasterized; the first one at or
  /// past the pending frame means a buffer of the new size reached the surface.
  void _onTimings(List<FrameTiming> timings) {
    final size = _pendingSize;
    if (size == null) return;
    for (final timing in timings) {
      if (_pendingFrame < 0 ||
          timing.frameNumber < 0 ||
          timing.frameNumber >= _pendingFrame) {
        _pendingSize = null;
        _reportedSize = size;
        _sendPresented(size);
        return;
      }
    }
  }

  void _sendPresented(Size size) {
    UXCamInternal.send('resizePresented', {
      'seq': _resizeSeq,
      'width': size.width.round(),
      'height': size.height.round(),
    });
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
