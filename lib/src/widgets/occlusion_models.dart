import 'dart:ui';

/// Supported occlusion styles for the wrapper.
enum OcclusionType { overlay, blur, none }

/// Contract implemented by render objects that report occlusion bounds.
abstract class OcclusionReportingRenderBox {
  int get stableId;
  Rect? get currentBounds;
  OcclusionType get currentType;
  double get devicePixelRatio;
  int get viewId;
  int get lastBoundsTimestampMicros;
}

abstract class ScrollSubscriber {
  void onScrollPositionChanged();
  void onScrollStateChanged(bool isScrolling);
}

class OcclusionUpdate {
  const OcclusionUpdate({
    required this.id,
    required this.bounds,
    required this.type,
    required this.devicePixelRatio,
    required this.viewId,
    required this.timestampMicros,
  });

  final int id;
  final Rect? bounds; // null signals removal
  final OcclusionType type;
  final double devicePixelRatio;
  final int viewId;
  final int timestampMicros;
}
