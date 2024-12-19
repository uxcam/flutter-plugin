
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
    final rects = <OccludePoint>[];
    // Preventing Extra Operation
    for (var wrapper in items) {
      var rect = wrapper.widget.getOccludePoint(wrapper.key);
      rects.add(rect);
    }
    return rects;
  }

  void updateOcclusionRects(OccludePoint rect) {
    occlusionRects.add(rect);
  }

  void resetOcclusionRect() {
    occlusionRects.clear();
  }


}
