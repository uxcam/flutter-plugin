import 'package:flutter/animation.dart';

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
