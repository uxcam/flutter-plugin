
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
          debugPrint("Occlusion Rects: bounds $json");
          debugPrint("Occlusion Rects: Waiting for resume rendering.");
          await _resumeRendering();
          debugPrint("Data from requestAllOcclusionRects: $json");
          return json;
        } else if (call.method == "pauseRendering") {
          debugPrint("Occlusion Rects: Pause rendering initiated.");
          var status = await _pauseRendering();
          debugPrint("Occlusion Rects: Pause rendering status: $status");
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
      debugPrint("Occlusion Rects: Already paused rendering");
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      // Immediate state update
      _isRenderingPaused = true;
      _preventRender = true;

      debugPrint("Occlusion Rects: Rendering visibility notified");
      VisibilityDetectorController.instance.notifyNow();
      // Ensure frame handling is synchronized
      await WidgetsBinding.instance.endOfFrame;

      if (_preventRender) {
        if (!_isFrameDeferred) {
          WidgetsBinding.instance.deferFirstFrame();
          _isFrameDeferred = true;
        }

        _cachedData = _handleRequestData();
        
        // Wait for frame to complete deferring
        await WidgetsBinding.instance.endOfFrame;
        debugPrint("Occlusion Rects: Rendering paused successfully");
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
      debugPrint("Occlusion Rects: Error pausing render: $e");
      return false;
    }
  }

  static Future<bool> _resumeRendering() async {
    if (!_isRenderingPaused) {
      debugPrint("Occlusion Rects: Already resumed rendering");
      debugPrint("Occlusion Rects: Rendering visibility notified after resume");
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      debugPrint("Occlusion Rects: Resuming rendering");
      
      // Update state immediately
      _isRenderingPaused = false;
      _preventRender = false;

      // Ensure frame scheduling is synchronized
      await WidgetsBinding.instance.endOfFrame;
      VisibilityDetectorController.instance.notifyNow();

      // Allow frames to resume
      if (_isFrameDeferred) {
        WidgetsBinding.instance.allowFirstFrame();
        _isFrameDeferred = false;
      }

      debugPrint("Occlusion Rects: Rendering visibility notified after resume");
      VisibilityDetectorController.instance.notifyNow();
      // Wait for frame to complete
      await WidgetsBinding.instance.endOfFrame;
      debugPrint("Occlusion Rects: Resumed rendering successfully");


      return true;
    } catch (e) {
      // Restore state on error
      _isRenderingPaused = true;
      _preventRender = true;
      debugPrint("Occlusion Rects: Error resuming render: $e");
      return false;
    }
  }

  /// This method collects the occlusionWrapper Rects as list.
  static List<Map<String, dynamic>> _handleRequestData() {
    var instance = OcclusionWrapperManager();
    var rects = instance.fetchOcclusionRects();
    return rects;
  }

}