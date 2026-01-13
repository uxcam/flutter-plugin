import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/occlude_render_box.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager_ios.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';

/// Handles synchronized capture requests from native to ensure
/// screenshot and occlusion rect collection happen atomically.
///
/// This solves scroll synchronization issues by inverting control:
/// instead of native taking screenshots at an uncertain time relative
/// to rect capture, Flutter collects rects and then calls native to
/// take the screenshot immediately with those exact rects.
class SynchronizedCaptureHandler {
  static const MethodChannel _captureChannel =
      MethodChannel('uxcam_synchronized_capture');

  static bool _isCaptureInProgress = false;
  static bool _isInitialized = false;

  /// Initialize the synchronized capture handler.
  /// Should be called once during plugin initialization.
  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _captureChannel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'synchronizedCapture':
        return _handleSynchronizedCapture(
          call.arguments as Map<dynamic, dynamic>?,
        );
      case 'cancelCapture':
        return _cancelCurrentCapture();
      default:
        throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'Method ${call.method} not supported',
        );
    }
  }

  /// Handles a synchronized capture request from native.
  ///
  /// Flow:
  /// 1. Wait for current frame to complete
  /// 2. Signal OccludeRenderBox to extend sliding window
  /// 3. Collect rects atomically from both registry and legacy manager
  /// 4. Call native to take screenshot WITH the rects
  /// 5. Return result
  static Future<Map<String, dynamic>> _handleSynchronizedCapture(
    Map<dynamic, dynamic>? arguments,
  ) async {
    final int captureId = (arguments?['captureId'] as int?) ?? 0;
    final int priority = (arguments?['priority'] as int?) ?? 0;

    // Check app lifecycle - skip if not resumed
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return {
        'status': 'skipped',
        'reason': 'app_not_resumed',
        'captureId': captureId,
      };
    }

    // Debounce: skip if capture already in progress (unless high priority)
    if (_isCaptureInProgress && priority == 0) {
      return {
        'status': 'skipped',
        'reason': 'capture_in_progress',
        'captureId': captureId,
      };
    }

    _isCaptureInProgress = true;

    try {
      // 1. Wait for frame to complete rendering
      await _waitForFrameStable();

      // 2. Signal capture imminent - extend sliding window
      OccludeRenderBox.signalCaptureImminent();

      // 3. Collect rects atomically at this exact moment
      final rects = _collectRectsAtomically();

      // 4. CRITICAL: Call native to take screenshot WITH the rects
      // The screenshot happens INSIDE this native call, ensuring atomicity
      final result = await _captureChannel.invokeMethod<Map<dynamic, dynamic>>(
        'takeScreenshotWithRects',
        {
          'captureId': captureId,
          'rects': rects,
          'timestamp': DateTime.now().microsecondsSinceEpoch,
        },
      ).timeout(
        const Duration(milliseconds: 100),
        onTimeout: () {
          // Timeout fallback - return rects for native to handle
          return {
            'status': 'timeout',
            'rects': rects,
          };
        },
      );

      return {
        'status': 'success',
        'captureId': captureId,
        'rectCount': rects.length,
        'nativeResult': result,
      };
    } catch (e) {
      return {
        'status': 'error',
        'captureId': captureId,
        'error': e.toString(),
      };
    } finally {
      OccludeRenderBox.signalCaptureComplete();
      _isCaptureInProgress = false;
    }
  }

  /// Waits for the current frame to complete rendering.
  /// Uses both postFrameCallback and endOfFrame for stability.
  static Future<void> _waitForFrameStable() async {
    final completer = Completer<void>();

    // Use addPostFrameCallback to ensure we're at a stable point
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Also wait for endOfFrame with timeout
    try {
      await Future.any([
        completer.future,
        WidgetsBinding.instance.endOfFrame.timeout(
          const Duration(milliseconds: 16), // One frame at 60fps
        ),
      ]);
    } catch (_) {
      // Timeout is acceptable, proceed anyway
    }

    // Ensure completer completes
    if (!completer.isCompleted) {
      await completer.future.timeout(
        const Duration(milliseconds: 16),
        onTimeout: () {},
      );
    }
  }

  /// Collects occlusion rects atomically from all sources.
  /// Combines rects from OcclusionRegistry (new system) and
  /// OcclusionWrapperManagerIOS (legacy system for backward compatibility).
  static List<Map<String, dynamic>> _collectRectsAtomically() {
    // Collect from OcclusionRegistry (uses historical bounds union)
    final registryRects = OcclusionRegistry.instance.getCachedRects();

    // Also collect from legacy manager for backward compatibility
    final legacyRects = OcclusionWrapperManagerIOS().fetchOcclusionRects();

    // Convert legacy format to match registry format if needed
    final convertedLegacyRects = legacyRects.map((rect) {
      // Legacy format uses x0,y0,x1,y1; convert to left,top,right,bottom
      if (rect.containsKey('x0')) {
        return {
          'id': rect['id'] ?? 0,
          'left': rect['x0'],
          'top': rect['y0'],
          'right': rect['x1'],
          'bottom': rect['y1'],
          'type': rect['type'] ?? 0,
        };
      }
      return rect;
    }).toList();

    // Merge and return (registry rects first, then legacy)
    return [...registryRects, ...convertedLegacyRects];
  }

  /// Cancels any in-progress capture.
  static Future<bool> _cancelCurrentCapture() async {
    _isCaptureInProgress = false;
    OccludeRenderBox.signalCaptureComplete();
    return true;
  }
}
