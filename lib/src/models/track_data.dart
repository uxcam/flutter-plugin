import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';

class TrackData {
  Rect bound;
  String route;
  String? uiValue;
  String? uiId;
  String? uiClass;
  int uiType;
  int depth;
  bool? isViewGroup;
  Map<String, dynamic>? custom;

  TrackData(
    this.bound,
    this.route, {
    this.uiValue = "",
    this.uiClass,
    this.uiType = -1,
    this.uiId,
    this.isViewGroup,
    this.depth = -1,
  });

  void setLabel(String label) {
    this.uiValue = label;
  }

  void setId(String id) {
    this.uiId = "${uiClass}_$id";
  }

  void addCustomProperty(Map<String, dynamic> customProperty) {
    if (custom == null) {
      custom = {};
    }
    custom!.addAll(customProperty);
  }

  TrackData copy() => TrackData(bound, route,
      uiValue: uiValue, uiClass: uiClass, uiType: uiType, uiId: uiId);

  @override
  String toString() {
    return 'TrackData(bound: $bound,  route: $route, id: $uiId, value: $uiValue)';
  }

  Map<String, dynamic> toJson() {
    return {
      'class': uiClass,
      'id': uiId,
      'value':
          jsonEncode(uiValue != null && uiValue!.isNotEmpty ? uiValue : ""),
      'type': uiType,
      'isViewGroup': isViewGroup ?? false,
      'bound': {
        "left": bound.left,
        "top": bound.top,
        "right": bound.right,
        "bottom": bound.bottom,
      },
      "custom": custom ?? {},
    };
  }

  void showAnalyticsInfo() {
    print("Element bound : $bound");
    print("Element id : $uiId");
    print("Element value : $uiValue");
    print("Element type : $uiType");
  }
}
