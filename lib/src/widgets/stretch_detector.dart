import 'package:flutter/widgets.dart';

import 'stretch_map.dart';

/// An overscroll stretch the box's transform chain cannot see.
///
/// On Impeller, Flutter 3.38+ draws `StretchEffect` with an `ImageFiltered`
/// shader, so `getTransformTo(null)` returns the unstretched position. Without
/// shader support it falls back to a `Transform`, which needs nothing here.
class ShaderStretch {
  const ShaderStretch(this.filter, this.strength, this.axis);

  final RenderBox filter;
  final double strength;
  final Axis axis;

  /// [rect] grown to also cover where the stretch draws it. A union, not a
  /// move: until the shader loads, the enabled filter draws content in place.
  Rect cover(Rect rect) {
    final container = MatrixUtils.transformRect(
        filter.getTransformTo(null), Offset.zero & filter.size);
    return rect
        .expandToInclude(StretchMap.remapRect(rect, container, axis, strength));
  }
}

final Expando<bool> _isStretchFilter = Expando<bool>('uxcamStretchFilter');

/// Shader stretches above [from], innermost first.
///
/// `StretchEffect` does not exist on older Flutter, so it is matched by shape:
/// an enabled `ImageFiltered` whose grandparent has `stretchStrength` and
/// `axis`, read through `dynamic`.
List<ShaderStretch> findShaderStretches(Element from) {
  final found = <ShaderStretch>[];
  Element? filter;
  var levelsAbove = 0;
  from.visitAncestorElements((element) {
    final pending = filter;
    if (pending != null && ++levelsAbove == 2) {
      final stretch = _readStretch(pending, element);
      if (stretch != null) found.add(stretch);
      filter = null;
    }
    final widget = element.widget;
    if (widget is ImageFiltered &&
        widget.enabled &&
        _isStretchFilter[element] != false) {
      filter = element;
      levelsAbove = 0;
    }
    return true;
  });
  return found;
}

ShaderStretch? _readStretch(Element filter, Element stretchEffect) {
  final box = filter.renderObject;
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  Object? strength;
  Object? axis;
  try {
    final dynamic widget = stretchEffect.widget;
    strength = widget.stretchStrength;
    axis = widget.axis;
  } on NoSuchMethodError {
    // Not a StretchEffect.
  }
  if (strength is! double || axis is! Axis) {
    _isStretchFilter[filter] = false;
    return null;
  }
  _isStretchFilter[filter] = true;
  if (strength.abs() <= 1e-10) return null;
  return ShaderStretch(box, strength, axis);
}
