
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';

class OcclusionWrapperItem {
  final OccludeWrapper widget;
  final GlobalKey key;

  const OcclusionWrapperItem(this.widget, this.key);
}

class OcclusionWrapperManager {

  OcclusionWrapperManager._privateConstructor();

  static final OcclusionWrapperManager _instance = OcclusionWrapperManager._privateConstructor();

  static OcclusionWrapperManager get instance => _instance;

  final items = <OcclusionWrapperItem>[];

  final occlusionRects = <OccludePoint>[];

/// Register Flutter Widget for occlusion
  void registerOcclusionWrapper(OcclusionWrapperItem item) {
    items.add(item);
  }

  /// UnRegister Occlusion Wrapper Widget for removing occlusion rect
  void unRegisterOcclusionWrapper(OcclusionWrapperItem item) {
    if (items.isNotEmpty) {
      items.removeWhere((item) => item.widget.hashCode == item.widget.hashCode);
    }
  }

  List<OccludePoint> getOccludePoints() {
    return items.map((wrapper) => wrapper.widget.getOccludePoint(wrapper.key)).toList();
  }

  void updateOcclusionRects(OccludePoint rect) {
    occlusionRects.add(rect);
  }

  void resetOcclusionRect() {
    occlusionRects.clear();
  }

  List<Map<String, dynamic>> sendOcclusionRects() {
    var _occlusionPoints = getOccludePoints();
    var json = _occlusionPoints.map((rect) => rect.toJson()).toList();
    return json;
  }


}
