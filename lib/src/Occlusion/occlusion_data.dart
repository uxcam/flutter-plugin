import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';

class OccludeData {
  OccludePoint point;
  GlobalKey key;

  OccludeData(this.key, this.point);

  @override
  String toString() {
    return 'OccludeData( point: $point)';
  }

  Map<String, dynamic> toJson() {
    return {
      "key": key,
      "point": point.toJson(),
    };
  }
}

class OccludePoint {
  int topLeftX;
  int topLeftY;
  int bottomRightX;
  int bottomRightY;

  OccludePoint(
    this.topLeftX,
    this.topLeftY,
    this.bottomRightX,
    this.bottomRightY,
  );

  @override
  String toString() {
    return 'OccludePoint(topLeftX: $topLeftX, topLeftY: $topLeftY, bottomRightX: $bottomRightX, bottomRightY: $bottomRightY)';
  }

  Map<String, dynamic> toJson() {
    return {
      "x0": topLeftX,
      "y0": topLeftY,
      "x1": bottomRightX,
      "y1": bottomRightY,
    };
  }

  Rect toRect() {
    return Rect.fromLTRB(
      topLeftX.toDouble(),
      topLeftY.toDouble(),
      bottomRightX.toDouble(),
      bottomRightY.toDouble(),
    );
  }
}


extension UtilIntExtension on double {
  int get toNative {
    final bool isAndroid = Platform.isAndroid;
    final double pixelRatio =
        PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (this * (isAndroid ? pixelRatio : 1.0)).toInt();
  }

  int get toFlutter {
    final bool isAndroid = Platform.isAndroid;
    final double pixelRatio =
        PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (this / (isAndroid ? pixelRatio : 1.0)).toInt();
  }
}