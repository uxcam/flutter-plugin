import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';

class OcclusionEventCollector {
  static final OcclusionEventCollector _instance =
      OcclusionEventCollector._internal();
  factory OcclusionEventCollector() => _instance;
  OcclusionEventCollector._internal();

  final keyRectMap = <GlobalKey, OccludePoint>{};

  void updateKeyMapping(GlobalKey key, OccludePoint occludePoint) {
    keyRectMap[key] = occludePoint;
  }

  void clearKeyMapping() {
    keyRectMap.clear();
  }

  List<GlobalKey> collectOcclusionKeys() {
    return OcclusionWrapperManager().getWrappers().map((e) => e.key).toList();
  }

  List<OccludePoint> collectOcclusionRects() {
    return OcclusionWrapperManager().occlusionRects.values.toList();
  }

  void clearOcclusionRects() {
    OcclusionWrapperManager().clearOcclusionRects();
  }
}
