import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class OcclusionManager {
  OcclusionManager._privateConstructor();

  static final OcclusionManager _instance =
      OcclusionManager._privateConstructor();

  factory OcclusionManager() => _instance;

  final temporalRectMap = <int, List<OccludeData>>{};

  void add(int timeStamp, GlobalKey key, Rect rect) {
    final data = OccludePoint(
      rect.left.toNative,
      rect.top.toNative,
      rect.right.toNative,
      rect.bottom.toNative,
    );
    FlutterUxcam.addFrameData(timeStamp, data.toJson().toString());
  }

  List<OccludePoint> getDataByTimestamp(int timestamp) {
    int effectiveTimeStamp = -1;
    try {
      effectiveTimeStamp =
          temporalRectMap.keys.lastWhere((key) => timestamp >= key);
    } on StateError {
      return [];
    }
    final result = temporalRectMap[effectiveTimeStamp] ?? [];
    print("found timeStamp($timestamp) : $result");
    //temporalRectMap.removeWhere((key, value) => effectiveTimeStamp > key);
    return result.map((e) => e.point).toList();
  }
}
