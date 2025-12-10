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
}

class OcclusionUpdate {
  const OcclusionUpdate({
    required this.id,
    required this.bounds,
    required this.type,
    required this.devicePixelRatio,
    required this.viewId,
  });

  final int id;
  final Rect? bounds; // null signals removal
  final OcclusionType type;
  final double devicePixelRatio;
  final int viewId;
}
