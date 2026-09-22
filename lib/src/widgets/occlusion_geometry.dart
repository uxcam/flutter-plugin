import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';


/// Geometry shared by every occlusion-reporting render box.

typedef VisibilityChecker = bool Function(
    RenderObject ancestor, RenderObject child);

/// Ancestor render-object types that need a bespoke visibility rule beyond the
/// generic `paintsChild` check.
///
/// Keyed by exact runtime type. Consulted only for `RenderStack` and
/// `RenderViewport` instances (see [_edgeState]) — the two families the keys
/// belong to — so the ~60 other ancestors on a typical chain skip the lookup.
final Map<Type, VisibilityChecker> _visibilityCheckers = {
  RenderIndexedStack: _checkIndexedStackVisibility,
  RenderViewport: _checkViewportVisibility,
};

bool _checkIndexedStackVisibility(RenderObject ancestor, RenderObject child) {
  final indexedStack = ancestor as RenderIndexedStack;
  final displayedIndex = indexedStack.index;
  if (displayedIndex == null) return false;

  int childIndex = 0;
  RenderBox? current = indexedStack.firstChild;
  while (current != null) {
    if (current == child) {
      return childIndex == displayedIndex;
    }
    childIndex++;
    current = indexedStack.childAfter(current);
  }
  return false;
}

bool _checkViewportVisibility(RenderObject ancestor, RenderObject child) {
  final viewport = ancestor as RenderViewport;

  RenderSliver? sliver;
  RenderObject? current = child;
  while (current != null && current != viewport) {
    if (current is RenderSliver) {
      sliver = current;
      break;
    }
    current = current.parent;
  }

  if (sliver == null) return true;

  final geometry = sliver.geometry;
  if (geometry == null || !geometry.visible) return false;

  return geometry.paintExtent > 0;
}

/// Everything an occlusion box needs about its position, resolved in a single
/// ancestor-chain traversal.
class OcclusionGeometry {
  const OcclusionGeometry({
    required this.isVisible,
    required this.transform,
    required this.clip,
  });

  /// False when the node is not actually painted (parent skips it, hidden
  /// `IndexedStack` branch, off-screen sliver). Layer-based opacity checks stay
  /// with the callers that own a layer.
  final bool isVisible;

  /// Maps the node's local coordinates to global (root) coordinates. Equivalent
  /// to `node.getTransformTo(null)`. Shared with the pass memo — read it, do not
  /// mutate it.
  final Matrix4 transform;

  /// Accumulated ancestor paint clip in global coordinates, or `null` when
  /// nothing clips the node.
  final Rect? clip;
}

/// The resolved state of one render object: its transform to global space, the
/// clip accumulated from the root down to and including the edge into it, and
/// whether every edge on that path paints its child.
///
/// A tree has exactly one path from the root to any node, so this state is the
/// same whichever descendant is being resolved — which is what lets it be
/// memoised across the fields of one pass.
class _ChainState {
  const _ChainState(this.transform, this.clip, this.visible);

  final Matrix4 transform;
  final Rect? clip;
  final bool visible;
}

/// The root's state: it has no edge into it. Its identity matrix is shared and
/// never mutated — every edge below clones before composing.
final _ChainState _rootState = _ChainState(Matrix4.identity(), null, true);

/// Per-pass memo of ancestor states, keyed by identity. Valid only while the
/// tree does not change, which is why it lives no longer than a pass.
final Map<RenderObject, _ChainState> _passStates =
    HashMap<RenderObject, _ChainState>.identity();

int _passDepth = 0;

/// Scratch buffer for the uncached part of a chain, reused across calls so no
/// list is allocated per field. Cleared on the way out so it pins nothing
/// between calls.
final List<RenderObject> _chainBuffer = <RenderObject>[];

/// Edges resolved since the last reset — a work count for tests.
@visibleForTesting
int debugEdgesComputed = 0;

@visibleForTesting
int get debugPassCacheSize => _passStates.length;

/// Opens a geometry pass: every [resolveOcclusionGeometry] call until the
/// matching [endGeometryPass] shares one memo of ancestor states, so fields on
/// one screen — which share almost their whole chain — cost O(unique ancestors)
/// rather than O(fields × depth).
///
/// A pass must not span a layout change; open it around one batch of resolves
/// (one frame's refresh, one capture's serve) and close it in a `finally` so an
/// exception cannot leave a stale memo behind. Passes nest.
void beginGeometryPass() {
  _passDepth++;
}

void endGeometryPass() {
  if (_passDepth == 0) return;
  _passDepth--;
  if (_passDepth == 0) _passStates.clear();
}

/// Resolves visibility, global transform and effective clip in one pass over the
/// ancestor chain, replacing three separate traversals — one of which called
/// `getTransformTo` per clipping ancestor, making it O(depth × clips) alone.
///
/// Walking up, the chain is collected only as far as the first ancestor already
/// resolved in this pass (or the root). Walking back down, each edge composes its
/// parent's state — visibility, the clip globalised in the parent's frame, then
/// the parent's paint transform for this child — and is memoised for the next
/// field. Outside a pass the memo is used for this call and dropped.
///
/// A `RenderEditable` sits ~63 ancestors deep; with the memo, the second and
/// later fields of a screen resolve only the few edges below their shared
/// ancestor.
OcclusionGeometry resolveOcclusionGeometry(RenderBox node) {
  final implicitPass = _passDepth == 0;
  if (implicitPass) _passDepth = 1;

  // Upward: collect the nodes whose edge is not yet resolved, leaf first,
  // stopping at a memoised ancestor or at the root (which has no edge).
  _chainBuffer.clear();
  var base = _rootState;
  RenderObject current = node;
  while (true) {
    final cached = _passStates[current];
    if (cached != null) {
      base = cached;
      break;
    }
    final parent = current.parent;
    if (parent == null) break;
    _chainBuffer.add(current);
    current = parent;
  }

  // Downward: from the highest unresolved node to the leaf, one edge at a time.
  var state = base;
  for (var i = _chainBuffer.length - 1; i >= 0; i--) {
    final kid = _chainBuffer[i];
    state = _edgeState(kid.parent!, kid, state);
    _passStates[kid] = state;
  }

  final edges = _chainBuffer.length;
  debugEdgesComputed += edges;
  _chainBuffer.clear();
  if (implicitPass) {
    _passDepth = 0;
    _passStates.clear();
  }

  return OcclusionGeometry(
      isVisible: state.visible, transform: state.transform, clip: state.clip);
}

/// The state of [kid] given the state of its [parent]: one edge of the chain.
_ChainState _edgeState(RenderObject parent, RenderObject kid, _ChainState of) {
  var visible = of.visible;
  if (visible) {
    if (!parent.paintsChild(kid)) {
      visible = false;
    } else if (parent is RenderStack || parent is RenderViewport) {
      // `RenderIndexedStack extends RenderStack`; the map is still keyed by exact
      // type, so a subclass of either gets no checker — as before the guard.
      final checker = _visibilityCheckers[parent.runtimeType];
      if (checker != null && !checker(parent, kid)) visible = false;
    }
  }

  // The parent's transform maps parent-local to global, which is exactly the
  // frame its clip is expressed in — so the clip is globalised BEFORE the edge's
  // own paint transform is composed.
  var clip = of.clip;
  if (parent is RenderBox) {
    final localClip = parent.describeApproximatePaintClip(kid);
    if (localClip != null) {
      final globalClip = MatrixUtils.transformRect(of.transform, localClip);
      clip = clip?.intersect(globalClip) ?? globalClip;
    }
  }

  // The root's own paint transform is deliberately NOT applied. Flutter's
  // `getTransformTo(null)` stops one short of the root, so its result is in the
  // root child's coordinate space — logical pixels — not the root's device-pixel
  // space. Applying `RenderView`'s transform here would scale every rect by the
  // device pixel ratio, putting every mask at 3× its true position on a 3×
  // screen.
  final Matrix4 transform;
  if (parent.parent == null) {
    transform = of.transform;
  } else {
    transform = of.transform.clone();
    parent.applyPaintTransform(kid, transform);
  }

  return _ChainState(transform, clip, visible);
}
