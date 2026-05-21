import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_registry.dart';
import 'scroll_optimizer.dart';

class SynchronizedCaptureHandler {
  SynchronizedCaptureHandler._();

  static bool _captureInProgress = false;

  static const Duration _frameStableTimeout = Duration(milliseconds: 250);

  static Future<bool> handleProbe() async {
    ScrollOptimizer.install();
    return true;
  }

  static Future<Map<String, dynamic>> handleSynchronizedCapture(
    Map<dynamic, dynamic>? arguments,
  ) async {
    ScrollOptimizer.install();

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return _skipped('app_not_resumed');
    }

    if (_captureInProgress) {
      return _skipped('capture_in_progress');
    }

    // Velocity- and stability-aware scroll skip — fully encapsulated in
    // ScrollOptimizer. Returns a reason string when the tick should be
    // dropped, null when it should proceed to capture.
    final String? scrollSkipReason = ScrollOptimizer.evaluateSkipReason();
    if (scrollSkipReason != null) {
      return _skipped(scrollSkipReason);
    }

    _captureInProgress = true;
    try {
      await _waitForFrameStable();

      final rects = OcclusionRegistry.instance.getOcclusionRects();

      return <String, dynamic>{
        'status': 'ok',
        'rects': rects,
        'frameTimestampUs': DateTime.now().microsecondsSinceEpoch,
      };
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'flutter_uxcam',
        context: ErrorDescription('during synchronizedCapture'),
      ));
      return _skipped('error');
    } finally {
      _captureInProgress = false;
    }
  }

  static Map<String, dynamic> _skipped(String reason) {
    return <String, dynamic>{
      'status': 'skipped',
      'reason': reason,
      'rects': const <Map<String, dynamic>>[],
      'frameTimestampUs': DateTime.now().microsecondsSinceEpoch,
    };
  }

  static Future<void> _waitForFrameStable() async {
    final Completer<void> completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future.timeout(
      _frameStableTimeout,
      onTimeout: () {},
    );
  }
}
