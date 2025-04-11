import 'dart:ui';

import 'package:flutter/widgets.dart';

class TrackData {
  Offset origin;
  Size size;
  String route;
  String? uiValue;
  String? uiId;
  String? uiClass;
  String? uiType;
  Key? widgetKey;

  TrackData(this.origin, this.size, this.route,
      {this.uiValue, this.uiClass, this.uiType, this.uiId});

  @override
  String toString() {
    return 'TrackData(origin: $origin, size: $size, route: $route, id: $uiId)';
  }

  void showAnalyticsInfo() {
    print("Element class : $uiClass");
    print("Element id : $uiId");
    print("Element value : $uiValue");
    print("Element type : $uiType");
  }
}
