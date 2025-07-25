import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final OcclusionEventCollector _collector = OcclusionEventCollector();

  UxCam() {
    const BasicMessageChannel<String> occlusionRectsChannel =
        BasicMessageChannel<String>(
            "occlusion_rects_coordinates", StringCodec());
    occlusionRectsChannel.setMessageHandler((event) async {
      await SchedulerBinding.instance.endOfFrame;
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
  }

  updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }

  void removeTrackData() {
    _trackList.clear();
  }
}
