import 'dart:async';

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

  UxCam() {
    const BasicMessageChannel<String> occlusionRectsChannel =
        BasicMessageChannel<String>(
            "occlusion_rects_coordinates", StringCodec());
    occlusionRectsChannel.setMessageHandler((event) async {
      if (event == "collect_key") {
        collectedKeys = await _collector.collectOcclusionRectsFor();
        print("found widgets : ${collectedKeys.length}");
      } else if (event == "convert_key") {
        final points = _convertWidgetKeysToOccludeRects(collectedKeys);
        print("covnverted widgets : ${points.toString()}");
        collectedKeys = [];
        return points.toString();
      }
      return "";
    });
  }

  List<Map<String, dynamic>> _convertWidgetKeysToOccludeRects(
      List<GlobalKey> collectedData) {
    List<OccludePoint> _points = [];
    _points = collectedData.map((key) {
      return _convertKeyToOccRect(key)!;
    }).toList();
    return _points.map((e) => e.toJson()).toList();
  }

  OccludePoint? _convertKeyToOccRect(GlobalKey key) {
    final rect = key.globalPaintBounds;
    return OccludePoint(
      rect!.left.ratioToInt,
      rect.top.ratioToInt,
      rect.right.ratioToInt,
      rect.bottom.ratioToInt,
    );
  }
}
