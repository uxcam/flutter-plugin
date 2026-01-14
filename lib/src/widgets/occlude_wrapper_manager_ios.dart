
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class OcclusionWrapperItem {
  final UniqueKey id;
  final GlobalKey key;

  OcclusionWrapperItem({required this.id, required this.key});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OcclusionWrapperItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class OcclusionWrapperManagerIOS {
  OcclusionWrapperManagerIOS._privateConstructor();

  static final OcclusionWrapperManagerIOS _instance =
      OcclusionWrapperManagerIOS._privateConstructor(); 
  factory OcclusionWrapperManagerIOS() => _instance;

  final items = <OcclusionWrapperItem>[];

  final occlusionRects = <UniqueKey, OccludePoint>{};
  final rects = <GlobalKey, OccludePoint>{};

  void add(int timeStamp, GlobalKey key, Rect rect) {
    rects.remove(key);
    rects[key] = OccludePoint(
      rect.left.toNative,
      rect.top.toNative,
      rect.right.toNative,
      rect.bottom.toNative,
    );
  }

  void clearOcclusionRects() {
    occlusionRects.clear();
  }

  bool containsWidgetByKey(GlobalKey key) {
    return items.any((item) {
      return item.key == key;
    });
  }

  /// Register Flutter Widget for occlusion
  /// Uses weak reference approach - only stores item if not already present
  void registerOcclusionWrapper(OcclusionWrapperItem item) {
    if (!items.contains(item)) {
      items.add(item);
    }
  }

  /// UnRegister Occlusion Wrapper Widget for removing occlusion rect
  void unRegisterOcclusionWrapper(UniqueKey id) {
    if (items.isNotEmpty) {
      // Find the wrapper to get its key before removing
      final wrapperToRemove =
          items.where((wrapper) => wrapper.id == id).firstOrNull;

      items.removeWhere((wrapper) => wrapper.id == id);

      // Remove the corresponding rect entry
      if (wrapperToRemove != null) {
        rects.remove(wrapperToRemove.key);
      }

      if (occlusionRects.containsKey(id)) {
        occlusionRects.removeWhere((key, _) => key == id);
      }
    }
  }

  List<OcclusionWrapperItem> getWrappers() => List.unmodifiable(items);

  List<Map<String, dynamic>> fetchOcclusionRects() {
    var occlusionPoints = getOccludePoints();
    var json = occlusionPoints.map((rect) => rect.toJson()).toList();
    return json;
  }

  List<OccludePoint> getOccludePoints() {
    return items.map((wrapper) => getOccludePoint(wrapper.key)).toList();
  }

  OccludePoint getOccludePoint(GlobalKey<State<StatefulWidget>> key) {
    var occludePoint = OccludePoint(0, 0, 0, 0);

    Rect? bound = key.globalPaintBounds;

    if (bound == null) return occludePoint;

    occludePoint = OccludePoint(
      bound.left.toNative,
      bound.top.toNative,
      bound.right.toNative,
      bound.bottom.toNative,
    );

    return occludePoint;
  }
}
