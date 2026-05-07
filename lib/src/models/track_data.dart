import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
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
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final value =
        jsonEncode(uiValue != null && uiValue!.isNotEmpty ? uiValue : "");
    final effectiveclass = uiClass != null && uiClass!.isNotEmpty
        ? uiClass
        : isAndroid
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
      "id": isAndroid ? jsonEncode(uiId) : uiId,
      "value": isAndroid ? value : uiValue,
      "name": isAndroid ? value : uiValue,
      "class": effectiveclass,
    };
    return result;
  }
}
