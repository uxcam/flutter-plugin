import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'textfield_detector.dart';

/// Finds text fields via the focus tree rather than the render tree.
///
/// Cost scales with the number of focusable widgets instead of total screen
/// complexity: measured on a real form, 112k node visits against the render
/// walk's 2.1M, and 5 nodes examined per field found instead of 103.
///
/// Correctness is the constraint, not speed — a field the focus tree misses
/// renders normally and silently stops being masked. `focus_tree_detector_test`
/// asserts parity with [RenderEditableDetector] across every field type,
/// including `ExcludeFocus` and `ExcludeSemantics`.
class FocusTreeDetector implements TextFieldDetector {
  FocusTreeDetector();

  static const int _maxDescend = 12;

  /// Memoised focus node to editable. Most of the saving comes from here: the
  /// focus walk is cheap, the render descent below each node is not, and that
  /// mapping is stable while the field is mounted.
  ///
  /// Negative results are cached too, and matter more than positive ones —
  /// `ListTile` wraps content in an `InkWell`, which installs a `Focus` node, so
  /// a long list is many leaf nodes with no field beneath them. Caching a
  /// negative is safe because a field appearing later brings its own `Focus`
  /// node, which makes the cached node a non-leaf and stops it being consulted.
  ///
  /// The memo is bounded by the live focus tree, not by a size cap. Every leaf
  /// the walk visits is stamped with the walk's generation; an entry left with an
  /// older stamp belongs to a node the tree no longer holds, and is swept after
  /// the walk. A `FocusNode` keeps its `BuildContext` after disposal, so a memo
  /// that outlived its node would pin the node's element, widget, state and
  /// render subtree — a long list once retained hundreds of recycled rows this
  /// way, until a wholesale clear dropped them all at once.
  final Map<FocusNode, _FocusMemo> _memo = <FocusNode, _FocusMemo>{};

  /// Incremented per walk; the stamp a visited entry receives.
  int _generation = 0;

  /// Entries stamped during the current walk. When it equals the memo size,
  /// nothing is stale and the sweep is skipped — the common case.
  int _stampedThisWalk = 0;

  @override
  void collect(RenderObject root, Map<int, DiscoveredField> out) {
    _generation++;
    _stampedThisWalk = 0;
    _visit(FocusManager.instance.rootScope, out);
    _sweep();
  }

  @override
  void reset() {
    _memo.clear();
  }

  /// Memo entries, for tests that pin the bound.
  @visibleForTesting
  int get debugMemoSize => _memo.length;

  @visibleForTesting
  bool debugRemembers(FocusNode node) => _memo.containsKey(node);

  void _visit(FocusNode node, Map<int, DiscoveredField> out) {
    // Leaves only, and never a scope. A `FocusScopeNode` has the whole screen as
    // its render subtree, and `Scrollable` installs a plain `FocusNode` whose
    // subtree is the entire list; descending from either costs more than the walk
    // this replaces. A field's own node is always a leaf.
    if (node.children.isEmpty && node is! FocusScopeNode) {
      final editable = _editableFor(node);
      if (editable != null) {
        final decorator = findDecoratorAncestor(editable);
        final target = decorator ?? editable;
        out[identityHashCode(target)] =
            DiscoveredField(target, isBareEditable: decorator == null);
      }
    }

    for (final child in node.children) {
      _visit(child, out);
    }
  }

  RenderEditable? _editableFor(FocusNode node) {
    final memo = _memo[node];
    if (memo != null) {
      final cached = memo.editable;
      // A remounted field gets a new render object; serving the old one would
      // mask a stale rectangle.
      if (cached == null || cached.attached) {
        memo.generation = _generation;
        _stampedThisWalk++;
        return cached;
      }
    }

    RenderEditable? found;
    final renderObject = node.context?.findRenderObject();
    if (renderObject is RenderBox) {
      found = _findEditableUnder(renderObject, _maxDescend);
    }

    if (memo != null) {
      memo
        ..editable = found
        ..generation = _generation;
    } else {
      _memo[node] = _FocusMemo(found, _generation);
    }
    _stampedThisWalk++;
    return found;
  }

  /// Drops every entry the walk did not stamp — nodes no longer in the tree, or
  /// no longer leaves. Skipped when every entry was stamped, so a settled screen
  /// pays one integer comparison.
  void _sweep() {
    if (_stampedThisWalk >= _memo.length) return;
    _memo.removeWhere((_, memo) => memo.generation != _generation);
  }

  RenderEditable? _findEditableUnder(RenderObject node, int budget) {
    if (node is RenderEditable) return node;
    if (budget <= 0) return null;

    RenderEditable? found;
    node.visitChildren((child) {
      // `visitChildren` cannot stop early; skipping the remaining siblings'
      // subtrees once a hit exists is the next best thing.
      if (found != null) return;
      found = _findEditableUnder(child, budget - 1);
    });
    return found;
  }
}

class _FocusMemo {
  _FocusMemo(this.editable, this.generation);

  /// The editable under the node, or null when there is none — a cached
  /// negative.
  RenderEditable? editable;

  /// The last walk that saw this node as a live leaf.
  int generation;
}
