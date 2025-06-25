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
    return 'TrackData(bound: $bound,  route: $route, id: $uiId, type: $uiType,value: $uiValue,)';
  }

  Map<String, dynamic> toJson() {
    final value =
        jsonEncode(uiValue != null && uiValue!.isNotEmpty ? uiValue : "");
    final effectiveclass = uiClass != null && uiClass!.isNotEmpty
        ? uiClass
        : Platform.isAndroid
            ? jsonEncode("")
            : "";
    Map<String, dynamic> result = {
      'isViewGroup': isViewGroup ?? false,
      'isSensitive': isSensitive,
      "type": uiType,
      'bound': {
        "left": bound.left,
        "top": bound.top,
        "right": bound.right,
        "bottom": bound.bottom,
      },
      "custom": custom ?? {},
      "id": Platform.isAndroid ? jsonEncode(uiId) : uiId,
      "value": Platform.isAndroid ? value : uiValue,
      "name": Platform.isAndroid ? value : uiValue,
      "class": effectiveclass,
    };
    return result;
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

class SummaryTree {
  Rect bound;
  String route;
  String uiClass;
  int type;
  int hashCode;
  String value;
  Map<String, dynamic> custom;
  List<SummaryTree> subTrees;
  bool isViewGroup;
  bool isOccluded;

  SummaryTree(
    this.route,
    this.uiClass,
    this.type,
    this.hashCode, {
    this.bound = Rect.zero,
    this.value = "",
    this.subTrees = const [],
    this.custom = const {},
    this.isViewGroup = false,
    this.isOccluded = false,
  });
}
