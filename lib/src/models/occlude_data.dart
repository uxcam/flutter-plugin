class OccludeData {
  OccludePoint point;
  String? routeName;
  String? type;

  OccludeData(this.type, this.routeName, this.point);

  Map<String, dynamic> toJson() {
    return {
      "name": routeName,
      "type": type,
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
}
