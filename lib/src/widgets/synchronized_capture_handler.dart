import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_registry.dart';

/// Option B handler: responds to native's `synchronizedCapture` method on the
/// `flutter_uxcam` channel. Waits for a stable Flutter frame, drains the
/// occlusion-rect state atomically, and returns the rects in the response
/// payload. Native takes the screenshot immediately upon receiving the
/// response — collapsing the screenshot/rect race window to microseconds.
///
/// Dispatched from [OcclusionRegistry] (which already owns the channel
/// handler) so we don't have to grab the `flutter_uxcam` channel away from
/// it. All methods are static — no instance state needed.
///
/// Protocol contract with UXFlutterSynchronizedCaptureBridge (iOS):
///   Method `synchronizedCaptureProbe` (no args)
///     → returns: true
///   Method `synchronizedCapture` (args: `{captureId: int}`)
///     → returns: `{status: 'ok'|'skipped',
///                  reason?: String,
///                  rects: [{x0, y0, x1, y1}],
///                  frameTimestampUs: int}`
class SynchronizedCaptureHandler {
  SynchronizedCaptureHandler._();

  /// Re-entrancy guard. iOS owns the cadence (CADisplayLink, max 5fps
  /// default), so concurrent invocations are rare — but the bridge can
  /// timeout-and-retry and we don't want two collectors racing.
  static bool _captureInProgress = false;

  /// Tighter than the native 500 ms watchdog. Bounds the worst case where
  /// PostFrameCallback never fires (paused engine, locked main thread).
  static const Duration _frameStableTimeout = Duration(milliseconds: 250);

  /// Probe handler. Native calls this once at bridge attach time to learn
  /// whether this Flutter build supports the synchronized capture flow.
  /// Returning anything non-error tells native "yes, use the synchronized
  /// source"; the bridge specifically tolerates `true`.
  static Future<bool> handleProbe() async {
    return true;
  }

  /// Synchronized-capture orchestrator. Returns a payload that native
  /// parses through `UXSynchronizedCaptureResponse`.
  static Future<Map<String, dynamic>> handleSynchronizedCapture(
    Map<dynamic, dynamic>? arguments,
  ) async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      // Backgrounded / inactive — let native skip without taking a snapshot.
      return _skipped('app_not_resumed');
    }

    if (_captureInProgress) {
      // Bridge already has a request in flight on the Dart side; native
      // will get an immediate skip and try again on the next tick.
      return _skipped('capture_in_progress');
    }

    _captureInProgress = true;
    try {
      // 1. Sync to the next stable Flutter frame. Ensures we collect rects
      //    *after* the current build/layout/paint pass settles — same
      //    instant native will see if it grabs the bitmap immediately.
      await _waitForFrameStable();

      // 2. Atomic snapshot. getOcclusionRects() is fully synchronous within
      //    a single Dart event-loop turn (it calls
      //    box.updateBoundsFromTransform() then reads the historical-bounds
      //    union for each entry), so no other Flutter work can interleave.
      final rects = OcclusionRegistry.instance.getOcclusionRects();

      // 3. Return to native — its bridge resolves the completion and
      //    UXFlutterSynchronizedFrameSource takes the screenshot
      //    immediately, using these rects in the same call stack.
      return <String, dynamic>{
        'status': 'ok',
        'rects': rects,
        'frameTimestampUs': DateTime.now().microsecondsSinceEpoch,
      };
    } catch (error, stack) {
      // Any unexpected failure during collection — native treats this as a
      // skip and retries next tick. Keep the recording cadence smooth.
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
    // If for whatever reason no frame is scheduled imminently, fall through
    // anyway. The collected rects will still be valid (just from the last
    // committed frame), and the bridge's 500 ms native watchdog gives us
    // ample headroom.
    await completer.future.timeout(
      _frameStableTimeout,
      onTimeout: () {},
    );
  }
}
