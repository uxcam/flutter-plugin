import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';

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

class OcclusionWrapperManager {
  OcclusionWrapperManager._privateConstructor();

  static final OcclusionWrapperManager _instance =
      OcclusionWrapperManager._privateConstructor();

  factory OcclusionWrapperManager() => _instance;

  final items = <OcclusionWrapperItem>[];

  final occlusionRects = <UniqueKey, OccludePoint>{};
  final rects = <GlobalKey, OccludePoint>{};

  void add(int timeStamp, GlobalKey key, Rect rect) {
    final data = OccludePoint(
      rect.left.ratioToInt,
      rect.top.ratioToInt,
      rect.right.ratioToInt,
      rect.bottom.ratioToInt,
    );

    rects.remove(key);
    rects[key] = data;

    List<Map<String, dynamic>> rectList = [];
    rects.forEach((key, value) {
      Map<String, dynamic> rectData = {
        "key": key.toString(),
        "point": value.toJson(),
      };
      rectList.add(rectData);
    });
    FlutterUxcam.addFrameData(timeStamp, jsonEncode(rectList));
  }

  void clearOcclusionRects() {
    occlusionRects.clear();
  }

  /// Register Flutter Widget for occlusion
  void registerOcclusionWrapper(OcclusionWrapperItem item) {
    if (!items.contains(item)) {
      items.add(item);
    }
  }

  /// UnRegister Occlusion Wrapper Widget for removing occlusion rect
  void unRegisterOcclusionWrapper(UniqueKey id) {
    if (items.isNotEmpty) {
      items.removeWhere((wrapper) => wrapper.id == id);
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
      bound.left.ratioToInt,
      bound.top.ratioToInt,
      bound.right.ratioToInt,
      bound.bottom.ratioToInt,
    );

    return occludePoint;
  }
}
