import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/occlusion_event_collector.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final OcclusionEventCollector _collector = OcclusionEventCollector();
  Completer<bool>? completer;
  List<GlobalKey> collectedKeys = [];
  bool _isRenderingPaused = false;
  bool _preventRender = false;
  bool _isFrameDeferred = false;

  UxCam() {
    const BasicMessageChannel<String> occlusionRectsChannel =
        BasicMessageChannel<String>(
            "occlusion_rects_coordinates", StringCodec());
    occlusionRectsChannel.setMessageHandler((event) async {
      if (event == "convert_key") {
        final points =
            _collector.collectOcclusionRects().map((e) => e.toJson()).toList();
        print("test: converted widgets : ${points.toString()}");
        _collector.clearOcclusionRects();
        return points.toString();
      } else if (event == "collect_key") {
        collectedKeys = _collector.collectOcclusionKeys();
        print("found widgets : ${collectedKeys.length}");
        return "";
      } else if (event == "pause_render") {
        _pauseRendering();
        return "";
      } else {
        _resumeRendering();
        return "";
      }
    });
  }

  // List<Map<String, dynamic>> _convertWidgetKeysToOccludeRects(
  //     List<GlobalKey> collectedData) {
  //   List<OccludePoint> _points = [];
  //   _points = collectedData.map((key) {
  //     return _convertKeyToOccRect(key)!;
  //   }).toList();
  //   return _points.map((e) => e.toJson()).toList();
  // }

  OccludePoint? _convertKeyToOccRect(GlobalKey key) {
    final rect = key.globalPaintBounds;
    return OccludePoint(
      rect!.left.ratioToInt,
      rect.top.ratioToInt,
      rect.right.ratioToInt,
      rect.bottom.ratioToInt,
    );
  }

  Future<bool> _pauseRendering() async {
    try {
      // Immediate state update
      // Ensure frame handling is synchronized
      await hasFrameEnded();

      _isRenderingPaused = true;
      _preventRender = true;

      if (_preventRender) {
        if (!_isFrameDeferred) {
          WidgetsBinding.instance.deferFirstFrame();
          _isFrameDeferred = true;
        }

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

  Future<bool> _resumeRendering() async {
    try {
      // Update state immediately
      _isRenderingPaused = false;
      _preventRender = false;

      // Ensure frame scheduling is synchronized
      await hasFrameEnded();

      // Allow frames to resume
      if (_isFrameDeferred) {
        WidgetsBinding.instance.allowFirstFrame();
        _isFrameDeferred = false;
      }

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

  Future<bool> hasFrameEnded() async {
    try {
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 150),
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
