import 'dart:ui';

import 'package:flutter/widgets.dart';

class TrackData {
  Rect bound;
  String route;
  String? uiValue;
  String? uiId;
  String? uiClass;
  int uiType;
  Key? widgetKey;

  TrackData(this.bound, this.route,
      {this.uiValue = "", this.uiClass, this.uiType = -1, this.uiId});

  void setLabel(String label) {
    this.uiValue = label;
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
      'value': uiValue,
      'type': uiType,
      'bound': bound,
    };
  }

  void showAnalyticsInfo() {
    print("Element bound : $bound");
    print("Element id : $uiId");
    print("Element value : $uiValue");
    print("Element type : $uiType");
  }
}
