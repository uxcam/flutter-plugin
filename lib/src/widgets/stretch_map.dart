import 'package:flutter/painting.dart';

/// Android's overscroll-stretch geometry, ported from AOSP
/// `libs/hwui/effects/StretchEffect.cpp` (as the Android SDK's `StretchMap.kt`).
/// Flutter's `stretch_effect.frag` is a port of the same file.
///
/// The shader maps rendered to layout; `reverseMap*` is its inverse, the
/// layout-to-rendered direction occlusion needs.
class StretchMap {
  StretchMap._();

  static double reverseMapStart(double overscroll, double input) {
    final numerator =
        (-input * overscroll * overscroll) - (2 * input * overscroll) - input;
    final denominator = 1.0 +
        (.3 * overscroll) +
        (.7 * input * overscroll * overscroll) +
        (.7 * input * overscroll);
    return -(numerator / denominator);
  }

  static double reverseMapEnd(double overscroll, double input) {
    final numerator = (.3 * overscroll * overscroll) -
        (.3 * input * overscroll * overscroll) +
        (1.3 * input * overscroll) -
        overscroll -
        input;
    final denominator = (.7 * input * overscroll * overscroll) -
        (.7 * input * overscroll) -
        (.7 * overscroll * overscroll) +
        overscroll -
        1.0;
    return numerator / denominator;
  }

  /// Where the normalised layout position [normalizedInput] renders. Positive
  /// [overscroll] anchors the start edge (top, left), negative the end edge.
  static double computeReverseOverscroll(
      double overscroll, double normalizedInput) {
    final distanceStretched = 1.0 / (1.0 + overscroll.abs());
    final distanceDiff = distanceStretched - 1.0;
    if (overscroll > 0) {
      final output = reverseMapStart(overscroll, normalizedInput);
      if (output <= 1.0) return output;
      if (output >= distanceStretched) return output - distanceDiff;
    }
    if (overscroll < 0) {
      final output = reverseMapEnd(overscroll, normalizedInput);
      if (output >= 0.0) return output;
      return output + distanceDiff;
    }
    return normalizedInput;
  }

  static double stretchedEdge(
    double position,
    double containerStart,
    double containerSize,
    double overscroll,
  ) {
    if (containerSize <= 0) return position;
    final u = (position - containerStart) / containerSize;
    return containerStart +
        containerSize * computeReverseOverscroll(overscroll, u);
  }

  /// [rect] where it renders when [container] is stretched along [axis].
  static Rect remapRect(
      Rect rect, Rect container, Axis axis, double overscroll) {
    if (axis == Axis.vertical) {
      final a =
          stretchedEdge(rect.top, container.top, container.height, overscroll);
      final b = stretchedEdge(
          rect.bottom, container.top, container.height, overscroll);
      return Rect.fromLTRB(rect.left, a, rect.right, b);
    }
    final a =
        stretchedEdge(rect.left, container.left, container.width, overscroll);
    final b =
        stretchedEdge(rect.right, container.left, container.width, overscroll);
    return Rect.fromLTRB(a, rect.top, b, rect.bottom);
  }
}
