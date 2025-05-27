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

  @override
  String toString() {
    return 'TrackData(bound: $bound,  route: $route, id: $uiId, value: $uiValue)';
  }

  void showAnalyticsInfo() {
    print("Element class : $uiClass");
    print("Element id : $uiId");
    print("Element value : $uiValue");
    print("Element type : $uiType");
  }
}
