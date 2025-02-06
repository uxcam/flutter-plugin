
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ChannelCallback {
  static bool _isRenderingPaused = false;
  static bool _preventRender = false;
  static List<Map<String, dynamic>> _cachedData = [];
  static bool _isFrameDeferred = false;

  static Future<void> handleChannelCallBacks(MethodChannel channel) async {

    VisibilityDetectorController.instance.updateInterval = Duration(seconds: 1);
    channel.setMethodCallHandler((MethodCall call) async {
      try {
        if (call.method == "requestAllOcclusionRects") {
          var json = _cachedData;
          // debugPrint("Occlusion Rects: bounds $json");
          // debugPrint("Occlusion Rects: Waiting for resume rendering.");
          await _resumeRendering();
          // debugPrint("Data from requestAllOcclusionRects: $json");
          return json;
        } else if (call.method == "pauseRendering") {
          // debugPrint("Occlusion Rects: Pause rendering initiated.");
          var status = await _pauseRendering();
          // debugPrint("Occlusion Rects: Pause rendering status: $status");
          return status;
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }


  static Future<bool> _pauseRendering() async {
    if (_isRenderingPaused) {
      // debugPrint("Occlusion Rects: Already paused rendering");
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      // Immediate state update

      // debugPrint("Occlusion Rects: Rendering visibility notified");
      VisibilityDetectorController.instance.notifyNow();
      // Ensure frame handling is synchronized
      await hasFrameEnded();

      _isRenderingPaused = true;
      _preventRender = true;

      if (_preventRender) {
        if (!_isFrameDeferred) {
          WidgetsBinding.instance.deferFirstFrame();
          // debugPrint("Occlusion Rects: Rendering frame deferred successfully");
          _isFrameDeferred = true;
        }

        _cachedData = _handleRequestData();
        
        // Wait for frame to complete deferring
        // debugPrint("Occlusion Rects: Rendering frame waiting end of frame");
        await hasFrameEnded();
        // debugPrint("Occlusion Rects: Rendering paused successfully");
      }


      return true;
    } catch (e) {
      // Reset state on error
      _isRenderingPaused = false;
      _preventRender = false;
      if (_isFrameDeferred) {
        WidgetsBinding.instance.allowFirstFrame();
        _isFrameDeferred = false;
      }
      // debugPrint("Occlusion Rects: Error pausing render: $e");
      return false;
    }
  }

  static Future<bool> _resumeRendering() async {
    if (!_isRenderingPaused) {
      // debugPrint("Occlusion Rects: Already resumed rendering");
      // debugPrint("Occlusion Rects: Rendering visibility notified after resume");
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      // debugPrint("Occlusion Rects: Resuming rendering");
      
      // Update state immediately
      _isRenderingPaused = false;
      _preventRender = false;

      // Ensure frame scheduling is synchronized
      await hasFrameEnded();
      VisibilityDetectorController.instance.notifyNow();

      // Allow frames to resume
      if (_isFrameDeferred) {
        WidgetsBinding.instance.allowFirstFrame();
        _isFrameDeferred = false;
      }

      // debugPrint("Occlusion Rects: Rendering visibility notified after resume");
      VisibilityDetectorController.instance.notifyNow();
      // Wait for frame to complete
      await hasFrameEnded();
      // debugPrint("Occlusion Rects: Resumed rendering successfully");


      return true;
    } catch (e) {
      // Restore state on error
      _isRenderingPaused = true;
      _preventRender = true;
      // debugPrint("Occlusion Rects: Error resuming render: $e");
      return false;
    }
  }

  /// This method collects the occlusionWrapper Rects as list.
  static List<Map<String, dynamic>> _handleRequestData() {
    var instance = OcclusionWrapperManager();
    var rects = instance.fetchOcclusionRects();
    return rects;
  }

  static Future<bool> hasFrameEnded() async {
    try {
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 100), // as to support 10fps at max
        onTimeout: () {
          return false;
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

}