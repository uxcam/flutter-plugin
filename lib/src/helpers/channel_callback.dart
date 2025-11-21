
import 'dart:async';

import 'package:flutter/scheduler.dart';
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
  static List<Map<String, dynamic>> _cachedData = [];
  
  // Optimization: Reuse frame deferral state
  static Completer<void>? _deferralCompleter;
  
  // Performance optimization: Batch deferrals
  static Timer? _deferralTimer;
  static DateTime _lastDeferralTime = DateTime.now();
  static const Duration _minDeferralInterval = Duration(milliseconds: 20);
  static const Duration _maxDeferralDuration = Duration(milliseconds: 100);

  static Future<void> handleChannelCallBacks(MethodChannel channel) async {

    // Use longer interval for visibility updates during normal operation
    VisibilityDetectorController.instance.updateInterval = Duration(milliseconds: 20);
    
    channel.setMethodCallHandler((MethodCall call) async {
      try {
        switch (call.method) {
          case FlutterChannelCallBackName.resumeWithData:
            _resumeRendering();
            final data = _cachedData;
            return data;
          case FlutterChannelCallBackName.pause:
            _pauseRendering();
            return true;
          default:
            return null;
        }
      } catch (e) {
        print('Error in channel callback: $e');
      }
    });
  }

  static void _pauseRendering() async {
    int timeoutMin = _minDeferralInterval.inMilliseconds;
    int timeoutMax = _maxDeferralDuration.inMilliseconds;
  
    _isRenderingPaused = true;
    
    // Start a timer to repeatedly collect occlusion data
    _deferralTimer?.cancel();
    DateTime startTime = DateTime.now(); // Record the start time
    _deferralTimer = Timer.periodic(Duration(milliseconds: timeoutMin), (timer) async {
      if (!_isRenderingPaused || DateTime.now().difference(startTime).inMilliseconds > timeoutMax) {
        timer.cancel(); // Stop the timer if rendering is resumed
        return;
      }

      // Notify visibility and collect occlusion data
      VisibilityDetectorController.instance.notifyNow();
      Future.delayed(Duration(milliseconds: 5)); // Small delay to allow updates
      try {
        List<Map<String, dynamic>> data = await _collectOcclusionDataOptimized()
          .timeout(Duration(milliseconds: timeoutMin-5), onTimeout: () => <Map<String, dynamic>>[]);
        _cachedData.addAll(data);
      } catch (e) {
        print('Error collecting occlusion data: $e');
      }
    });

    return;
  }

  // Optimized resume with validation
  static void _resumeRendering() async {
    _isRenderingPaused = false;
  }

  // Optimized occlusion data collection
  static Future<List<Map<String, dynamic>>> _collectOcclusionDataOptimized() async {
    final instance = OcclusionWrapperManager();
    
    // If frame is deferred, we can collect synchronously
    if (_isRenderingPaused) {
      try {
        return instance.fetchOcclusionRects();
      } catch (e) {
        print('fetchOcclusionRects error: $e');
        return [];
      }
    }
    
    // Otherwise, wait for next frame boundary (fast) with small timeout
    final completer = Completer<List<Map<String, dynamic>>>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final rects = instance.fetchOcclusionRects();
        if (!completer.isCompleted) completer.complete(rects);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });
    
    return await completer.future.timeout(
      Duration(milliseconds: 60),
      onTimeout: () {
        try {
          return instance.fetchOcclusionRects();
        } catch (e) {
          print('Timeout fetchOcclusionRects error: $e');
          return <Map<String, dynamic>>[];
        }
      },
    );
  }

  // Helper to wait for stable frame
  static Future<void> _waitForStableFrame() async {
    // Check if we're in a build phase
    if (WidgetsBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      // Wait for current frame to complete
      await WidgetsBinding.instance.endOfFrame;
    }
    
    // Additional small delay to ensure stability
    await Future.delayed(Duration(microseconds: 20));
  }

  // Clean up method
  static void cleanup() {
    _isRenderingPaused = false;
    _cachedData.clear();
    _deferralTimer?.cancel();
    _deferralTimer = null;
  }
}

class _FrameData {
  final DateTime timestamp;
  final List<Map<String, dynamic>> rects;
  
  _FrameData({
    required this.timestamp,
    required this.rects,
  });
}
