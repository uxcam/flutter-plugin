import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/occlusion_event_collector.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final OcclusionEventCollector _collector = OcclusionEventCollector();
  Completer<bool>? completer;

  UxCam() {
    const BasicMessageChannel<String> occlusionRectsChannel =
        BasicMessageChannel<String>(
            "occlusion_rects_coordinates", StringCodec());
    occlusionRectsChannel.setMessageHandler((event) async {
      completer = Completer<bool>();
      await _deferFirstFrame();
      final collectedData = await _collector.collectOcclusionRectsFor();
      final points = _convertOccludeDataToRects(collectedData);
      return points.toString();
    });
  }

  List<Map<String, dynamic>> _convertOccludeDataToRects(
      List<OccludeData> collectedData) {
    final currentStack = navigationObserver?.screenNames ?? [];
    if (currentStack.length == 1) {
      return collectedData.map((e) => e.point.toJson()).toList();
    }
    if (currentStack.isNotEmpty && currentStack.last == ":popup") {
      return [];
    } else {
      return collectedData.map((e) => e.point.toJson()).toList();
    }
  }

  Future<void> _deferToEndOfEveryFrame() async {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await SchedulerBinding.instance.endOfFrame;
    });
  }

  Future<bool> _deferFirstFrame() async {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      completer!.complete(true);
    });
    return completer!.future;
  }
}
