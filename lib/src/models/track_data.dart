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
  bool isInteractive = false;

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
    this.isInteractive = false,
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
      'isInteractive': isInteractive,
      "type": uiType,
      'bound': {
        "left": bound.left,
        "top": bound.top,
        "right": bound.right,
        "bottom": bound.bottom,
      },
      "custom": custom ?? {},
      "id": kIsWeb ? uiId : Platform.isAndroid ? jsonEncode(uiId) : uiId,
      "value": kIsWeb ? uiValue : Platform.isAndroid ? value : uiValue,
      "name": kIsWeb ? uiValue : Platform.isAndroid ? value : uiValue,
      "class": kIsWeb ? (uiClass ?? '') : effectiveclass,
    };
    return result;
  }
}
