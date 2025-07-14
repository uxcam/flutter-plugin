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
  bool isSensitive = false;

  TrackData(
    this.bound,
    this.route, {
    this.uiValue,
    this.uiClass,
    this.uiType = -1,
    this.uiId,
    this.isViewGroup,
    this.depth = -1,
    this.isSensitive = false,
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
    return 'TrackData(bound: $bound,  route: $route, id: $uiId, type: $uiType,value: $uiValue,)';
  }

  Map<String, dynamic> toJson() {
    final value =
        jsonEncode(uiValue != null && uiValue!.isNotEmpty ? uiValue : "");
    return {
      'class': uiClass,
      'id': uiId,
      'value': value,
      'name': uiValue,
      'type': uiType,
      'isViewGroup': isViewGroup ?? false,
      'isSensitive': isSensitive,
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

class SummaryTree {
  Rect bound;
  String route;
  String uiClass;
  int type;
  String value;
  Map<String, dynamic> custom;
  List<SummaryTree> subTrees;
  bool isViewGroup;

  SummaryTree(
    this.route,
    this.uiClass,
    this.type, {
    this.bound = Rect.zero,
    this.value = "",
    this.subTrees = const [],
    this.custom = const {},
    this.isViewGroup = false,
  });
}
