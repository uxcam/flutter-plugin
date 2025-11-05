
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FlutterChannelCallBackName {
  static const pause = "pauseRendering";
  static const resumeWithData = "requestAllOcclusionRects";
}

class ChannelCallback {
  static bool _isRenderingPaused = false;
  static bool _preventRender = false;
  static List<Map<String, dynamic>> _cachedData = [];
  static bool _isFrameDeferred = false;
  static bool _hasSeenFirstFrame = false;
  
  // Track pending frame resumption
  static Completer<void>? _pendingFrameCompletion;

  static Future<void> handleChannelCallBacks(MethodChannel channel) async {

    VisibilityDetectorController.instance.updateInterval = Duration(seconds: 1);
    channel.setMethodCallHandler((MethodCall call) async {
      try {
        if (call.method == FlutterChannelCallBackName.resumeWithData) {
          var json = _cachedData;
          await _resumeRendering();
          return json;
        } else if (call.method == FlutterChannelCallBackName.pause) {
          var status = await _pauseRendering();
          return status;
        }
        return null;
      } catch (e) {
        return null;
      }
    });
    
    // Track first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasSeenFirstFrame = true;
    });
  }

  /// Pause rendering without deferring frames - only for analytics capture
  static Future<bool> _pauseRendering() async {

    if (!_checkOcclusions()) { 
      _isRenderingPaused = false;
      _preventRender = false;
      return false;
    }

    if (_isRenderingPaused) {
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      // Wait for current frame to complete naturally
      await _waitForFrameCompletion();

      VisibilityDetectorController.instance.notifyNow();

      _isRenderingPaused = true;
      _preventRender = true;

      // Collect occlusion data for analytics
      _cachedData = _handleRequestData();
      
      // Schedule a frame to ensure rendering can resume later
      WidgetsBinding.instance.scheduleFrame();

      return true;
    } catch (e) {
      // Reset state on error
      _isRenderingPaused = false;
      _preventRender = false;
      return false;
    }
  }

  /// Resume rendering - always succeeds to prevent hangs
  static Future<bool> _resumeRendering() async {
    if (!_isRenderingPaused) {
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      // Update state immediately
      _isRenderingPaused = false;
      _preventRender = false;

      // Schedule a frame to resume rendering
      WidgetsBinding.instance.scheduleFrame();
      
      VisibilityDetectorController.instance.notifyNow();

      // Wait for frame to be scheduled
      await _waitForFrameCompletion();

      return true;
    } catch (e) {
      // Always reset to prevent permanent hang
      _isRenderingPaused = false;
      _preventRender = false;
      
      // Force frame scheduling as last resort
      WidgetsBinding.instance.scheduleFrame();
      
      return false;
    }
  }

  /// Wait for the current frame to complete without blocking
  static Future<void> _waitForFrameCompletion() async {
    try {
      // Use addPostFrameCallback for non-blocking frame sync
      final completer = Completer<void>();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      
      // With timeout to prevent indefinite waiting
      await completer.future.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () {
          // Timeout is OK - means frame already completed
          return;
        },
      );
    } catch (e) {
      // Ignore errors - frame completion is best-effort
    }
  }

  /// This method collects the occlusionWrapper Rects as list.
  static List<Map<String, dynamic>> _handleRequestData() {
    var instance = OcclusionWrapperManager();
    var rects = instance.fetchOcclusionRects();
    return rects;
  }

  /// This method checks the occlusionWrapper Rects as list.
  static bool _checkOcclusions() {
    var instance = OcclusionWrapperManager();
    var check = instance.hasOcclusionRects();
    return check;
  }

  /// Safely dispose resources
  static void dispose() {
    _isRenderingPaused = false;
    _preventRender = false;
    _hasSeenFirstFrame = false;
    _cachedData.clear();
    
    if (_pendingFrameCompletion != null && !_pendingFrameCompletion!.isCompleted) {
      _pendingFrameCompletion!.completeError('Disposed');
      _pendingFrameCompletion = null;
    }
    
    // Ensure rendering can resume
    try {
      WidgetsBinding.instance.scheduleFrame();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }
}
