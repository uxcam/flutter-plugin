import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'occlusion_geometry.dart';
import 'occlusion_models.dart';

/// Adapter that lets an arbitrary [RenderBox] discovered by the auto-textfield
/// scan participate in occlusion without living in the render tree itself.
///
/// Unlike [OccludeRenderBox] this object does not own the render box it masks —
/// it wraps a `RenderEditable` (or, preferably, the `InputDecorator`'s
/// decoration box) that the [OcclusionRegistry] found while walking the tree.
///
/// [addPadding] is `true` only when the scan fell back to a bare
/// `RenderEditable` (no `InputDecorator` ancestor). In that case the render box
/// covers just the glyph area, so we pad it to approximate the tappable field.
/// When the decoration box was found its bounds are already correct and no
/// padding is applied — avoiding an oversized mask.
class TextFieldOccludeRenderBox implements OcclusionReportingRenderBox {
  TextFieldOccludeRenderBox(
    this.renderBox, {
    this.addPadding = false,
    int Function()? clock,
  })  : _clock = clock ?? _wallClock,
        _stableId = stableIdFor(renderBox) {
    _createdMs = _clock();
  }

  /// The id an adapter over [box] will report, derivable before one exists so
  /// the owning store can index by it without constructing a throwaway adapter.
  static int stableIdFor(RenderBox box) =>
      Object.hash('textfield', identityHashCode(box));

  /// When this adapter was created, on the shared clock. Bounds the
  /// unknown-velocity margin — see [_unknownVelocityWindowMs].
  late final int _createdMs;

  /// Shared with the owning store so the window and the registry's cadence agree
  /// on the time. The window spans 100 ms of real time, so a private clock lets
  /// entries age out under load exactly when a lagging mask matters most.
  final int Function() _clock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final RenderBox renderBox;
  final bool addPadding;
  final int _stableId;
  Rect? _lastBounds;

  /// Sliding-window retention, matching [OccludeRenderBox], so a single dropped
  /// frame never unmasks the field.
  static const int _boundsWindowMs = 100;

  /// Worst-case staleness of a served rect: one bounds-refresh interval plus one
  /// frame of capture skew. Mirrors `OcclusionRegistry._boundsIntervalMs`.
  static const int _boundsRefreshIntervalMs = 33;
  static const int _captureSkewMs = 17;

  /// A transition moves a field ~2.7 px/ms over the 50 ms projection window.
  static const double _unknownVelocityMargin = 135.0;

  /// Bounds [_unknownVelocityMargin] by adapter age. A settled screen produces no
  /// frames, so the window empties and the sample count stays below two forever —
  /// without this the margin would never be withdrawn.
  static const int _unknownVelocityWindowMs = 150;

  /// Shortest gap between two samples that yields a usable velocity. Below this
  /// the divisor is noise rather than signal.
  static const int _minVelocitySampleMs = 8;

  /// Padding applied only to the bare-`RenderEditable` fallback.
  static const double _fallbackHorizontalPadding = 12.0;
  static const double _fallbackVerticalPadding = 16.0;

  final _timestampedBounds = <(int, Rect)>[];

  @override
  int get stableId => _stableId;

  @override
  bool get attached => renderBox.attached;

  @override
  bool get hasSize => renderBox.hasSize;

  @override
  OcclusionType get currentType => OcclusionType.overlay;

  @override
  Rect? get currentBounds => _lastBounds;

  @override
  double get devicePixelRatio =>
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  @override
  int get viewId => 0;

  @override
  void updateBoundsFromTransform() {
    if (!attached || !hasSize) return;

    final geometry = resolveOcclusionGeometry(renderBox);

    if (!geometry.isVisible) {
      _lastBounds = null;
      _timestampedBounds.clear();
      return;
    }

    var bounds = MatrixUtils.transformRect(
        geometry.transform, Offset.zero & renderBox.size);

    if (addPadding) {
      bounds = Rect.fromLTRB(
        bounds.left - _fallbackHorizontalPadding,
        bounds.top - _fallbackVerticalPadding,
        bounds.right + _fallbackHorizontalPadding,
        bounds.bottom + _fallbackVerticalPadding,
      );
    }

    final effectiveClip = geometry.clip;
    if (effectiveClip != null) {
      bounds = bounds.intersect(effectiveClip);
    }

    if (bounds.width > 0 && bounds.height > 0) {
      _lastBounds = bounds;
      final nowMs = _clock();
      _timestampedBounds.add((nowMs, bounds));
      _timestampedBounds.removeWhere((e) => (nowMs - e.$1) > _boundsWindowMs);
    } else {
      _lastBounds = null;
      _timestampedBounds.clear();
    }
  }

  @override
  void recalculateBounds() => updateBoundsFromTransform();

  @override
  void clearHistoricalBounds() {
    _timestampedBounds.clear();
    _lastBounds = null;
  }

  @override
  Rect? getUnionOfHistoricalBounds() {
    final nowMs = _clock();
    _timestampedBounds.removeWhere((e) => (nowMs - e.$1) > _boundsWindowMs);

    Rect? union;
    for (final (_, bounds) in _timestampedBounds) {
      union = union?.expandToInclude(bounds) ?? bounds;
    }
    union ??= _lastBounds;
    if (union == null) return null;

    return _withMotionMargin(union);
  }

  /// Extends [union] in the direction of travel.
  ///
  /// The union covers where the field has been, which guards a capture looking
  /// backwards but leaves the leading edge exposed during a transition — measured
  /// at 21 of 22 frames, up to 211 px. Projecting velocity forward over the
  /// worst-case staleness over-masks a moving field, which is the safe direction,
  /// and collapses to nothing once it stops.
  ///
  /// Every edge is projected independently, so a field that grows (a dialog or
  /// sheet scaling in) is covered as well as one that slides.
  Rect _withMotionMargin(Rect union) {
    if (_timestampedBounds.length < 2) return _withUnknownVelocityMargin(union);

    final (firstMs, firstRect) = _timestampedBounds.first;
    final (lastMs, lastRect) = _timestampedBounds.last;
    final windowMs = lastMs - firstMs;
    // Two samples inside the same millisecond are no more informative than one:
    // velocity is unknown, not zero. Falling through to the bare union here served
    // a field discovered mid-transition its exact current rect with no margin at
    // all, on the one frame it is growing fastest.
    if (windowMs <= 0) return _withUnknownVelocityMargin(union);

    final (prevMs, prevRect) =
        _timestampedBounds[_timestampedBounds.length - 2];
    final recentMs = lastMs - prevMs;

    const projectionMs = _boundsRefreshIntervalMs + _captureSkewMs;

    /// How far one edge should reach beyond [union], in the outward direction
    /// given by [outwardIsPositive].
    ///
    /// Takes whichever of the window-averaged and the most recent velocity
    /// travels further outward, because neither is safe alone and the two fail in
    /// opposite regimes. Averaging alone understates *acceleration*: a field that
    /// has been sitting still fills the window with identical samples, so the
    /// first frame of a fling or a route push projects almost nothing and every
    /// mask lags a full refresh interval — measured at 36 px on frame one of a
    /// hard fling, across every field on screen. The last delta alone understates
    /// *deceleration*: a route curve easing out makes the final frame's delta
    /// smaller than the travel still to come. Reaching for the larger of the two
    /// over-masks slightly in the safe direction and still collapses to nothing
    /// once the field stops.
    double outward(double Function(Rect) edge,
        {required bool outwardIsPositive}) {
      final averaged =
          (edge(lastRect) - edge(firstRect)) / windowMs * projectionMs;
      // Too short a gap makes the divisor noise: a capture-time refresh can land
      // a millisecond after a frame's, and dividing a 3 px step by 1 ms projects
      // 150 px of travel that is not coming.
      if (recentMs < _minVelocitySampleMs) return averaged;
      final recent =
          (edge(lastRect) - edge(prevRect)) / recentMs * projectionMs;
      return outwardIsPositive
          ? math.max(averaged, recent)
          : math.min(averaged, recent);
    }

    // Each edge is projected from its own velocity, not from the top-left
    // corner's. Deriving the whole rect's motion from one corner models pure
    // translation, where all four edges share a velocity — but a field that
    // *grows* has left/top and right/bottom moving in opposite directions. A
    // dialog or sheet scaling in is the common case: the corner-derived delta is
    // negative, so it extended the left edge and left the right and bottom edges
    // — the ones actually advancing — unextended and the field's leading edge
    // exposed for the whole transition.
    final dl = outward((r) => r.left, outwardIsPositive: false);
    final dt = outward((r) => r.top, outwardIsPositive: false);
    final dr = outward((r) => r.right, outwardIsPositive: true);
    final db = outward((r) => r.bottom, outwardIsPositive: true);

    // Only ever extend outward. An edge travelling inward is already covered by
    // the union of where the field has been, so shrinking here would cut into it.
    return Rect.fromLTRB(
      union.left + (dl < 0 ? dl : 0),
      union.top + (dt < 0 ? dt : 0),
      union.right + (dr > 0 ? dr : 0),
      union.bottom + (db > 0 ? db : 0),
    );
  }

  /// Velocity unknown — the modal case, where a sheet builds and starts animating
  /// in the same frame. Inflate in every direction, since the direction is unknown
  /// too, and bound it by adapter age: a settled screen produces no frames, so the
  /// window empties and the sample count stays below two forever — without the
  /// bound the margin would never be withdrawn.
  Rect _withUnknownVelocityMargin(Rect union) =>
      _clock() - _createdMs < _unknownVelocityWindowMs
          ? union.inflate(_unknownVelocityMargin)
          : union;
}
