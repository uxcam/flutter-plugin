
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager_ios.dart';
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
  }


  static Future<bool> _pauseRendering() async {
    if (_isRenderingPaused) {
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      // Immediate state update
      // Ensure frame handling is synchronized
      await hasFrameEnded();

      VisibilityDetectorController.instance.notifyNow();

      _isRenderingPaused = true;
      _preventRender = true;

      if (_preventRender) {
        if (!_isFrameDeferred) {
          WidgetsBinding.instance.deferFirstFrame();
          _isFrameDeferred = true;
        }

        _cachedData = _handleRequestData();
        
        // Wait for frame to complete deferring
        await hasFrameEnded();
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
      return false;
    }
  }

  static Future<bool> _resumeRendering() async {
    if (!_isRenderingPaused) {
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
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

      VisibilityDetectorController.instance.notifyNow();
      // Wait for frame to complete
      await hasFrameEnded();


      return true;
    } catch (e) {
      // Restore state on error
      _isRenderingPaused = true;
      _preventRender = true;
      return false;
    }
  }

  /// This method collects the occlusionWrapper Rects as list.
  static List<Map<String, dynamic>> _handleRequestData() {
    var instance = OcclusionWrapperManagerIOS();
    var rects = instance.fetchOcclusionRects();
    return rects;
  }

  static Future<bool> hasFrameEnded() async {
    try {
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 50), // as to support 10fps at max
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