import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A text field found by a scan: the box to mask, and whether it needs padding.
class DiscoveredField {
  const DiscoveredField(this.box, {required this.isBareEditable});

  /// The `InputDecorator` decoration box when found, otherwise the bare
  /// `RenderEditable`.
  final RenderBox box;

  /// True when [box] is a bare `RenderEditable` — the adapter pads it to
  /// approximate the tappable field.
  final bool isBareEditable;
}

/// Finds text fields. Implementations differ in how they search; what they
/// return, and therefore what gets masked, must not.
abstract class TextFieldDetector {
  void collect(RenderObject root, Map<int, DiscoveredField> out);
}

/// Ancestors to climb looking for the decorator.
///
/// `_RenderDecoration` sits 11 above the `RenderEditable` of a Material
/// `TextField`. A lower cap silently never reaches it, and the padded glyph-box
/// fallback covers the typed text but not the label, hint, prefix or suffix,
/// which the decorator paints outside it.
const int _maxDecoratorClimb = 24;

/// Slotted render objects that are not input decorators.
///
/// `ListTile` and `Chip` use the same mixin, so a field inside one would
/// otherwise mask the whole row. Unrecognised slotted types are treated as
/// decorators: an oversized mask is caught by a test, an unmasked field is not.
const Set<String> _nonDecoratorSlottedTypes = {
  '_RenderListTile',
  '_RenderChip',
};

/// The decoration box covering the full visible field, or null for undecorated
/// fields such as a raw `EditableText` or a `CupertinoTextField`.
RenderBox? findDecoratorAncestor(RenderEditable editable) {
  RenderObject? current = editable.parent;
  var depth = 0;
  while (current != null && depth < _maxDecoratorClimb) {
    if (current is SlottedContainerRenderObjectMixin) {
      if (_nonDecoratorSlottedTypes.contains(current.runtimeType.toString())) {
        return null;
      }
      return current as RenderBox;
    }
    current = current.parent;
    depth++;
  }
  return null;
}

/// Finds every `RenderEditable` by walking the render tree.
///
/// Complete by construction, and the reference [FocusTreeDetector] is asserted
/// against, but its cost scales with the whole tree rather than the field count.
class RenderEditableDetector implements TextFieldDetector {
  const RenderEditableDetector();

  @override
  void collect(RenderObject root, Map<int, DiscoveredField> out) {
    if (root is RenderEditable) {
      final decorator = findDecoratorAncestor(root);
      final target = decorator ?? root;
      out[identityHashCode(target)] =
          DiscoveredField(target, isBareEditable: decorator == null);
    }
    root.visitChildren((child) => collect(child, out));
  }
}
