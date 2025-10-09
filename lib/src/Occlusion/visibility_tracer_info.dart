import 'dart:ui';

import 'occlusion_data.dart';

/// Information about widget visibility and bounds
class VisibilityTrackerInfo {
  final bool isVisible;
  final Rect? bounds;
  final double visibilityFraction;
  final DateTime timestamp;
  final Size? widgetSize;
  final Offset? globalPosition;

  VisibilityTrackerInfo({
    required this.isVisible,
    this.bounds,
    required this.visibilityFraction,
    required this.timestamp,
    this.widgetSize,
    this.globalPosition,
  });

  OccludePoint toOccludePoint() {
    return OccludePoint(
      bounds?.left.toNative ?? 0,
      bounds?.top.toNative ?? 0,
      bounds?.right.toNative ?? 0,
      bounds?.bottom.toNative ?? 0,
    );
  }

  
}
