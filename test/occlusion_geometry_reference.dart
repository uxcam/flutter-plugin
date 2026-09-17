import 'package:flutter/rendering.dart';

// Reference implementations of the traversals that resolveOcclusionGeometry
// replaced, kept only so the single-pass version can be checked against them.
// Nothing in lib/ uses these.

typedef VisibilityChecker = bool Function(
    RenderObject ancestor, RenderObject child);

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
    if (current == child) return childIndex == displayedIndex;
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

/// Walks the ancestor chain of [node] and returns `true` when [node] is not
/// actually being painted (parent skips it, hidden `IndexedStack` branch,
/// off-screen sliver, etc.). Layer-based (opacity) checks are intentionally
/// left to callers that own a layer.
///
/// Prefer [resolveOcclusionGeometry] on any path that also needs the transform or
/// clip — it produces all three in one traversal instead of three.
bool isRenderObjectEffectivelyInvisible(RenderObject node) {
  RenderObject? child = node;
  RenderObject? ancestor = node.parent;

  while (ancestor != null) {
    if (!ancestor.paintsChild(child!)) {
      return true;
    }

    final checker = _visibilityCheckers[ancestor.runtimeType];
    if (checker != null && !checker(ancestor, child)) {
      return true;
    }

    child = ancestor;
    ancestor = ancestor.parent;
  }
  return false;
}

/// Accumulates the approximate paint clip of every ancestor of [node],
/// expressed in global (root) coordinates. Returns `null` when nothing clips
/// the node.
///
/// Note the cost: this calls `getTransformTo(null)` per clipping ancestor, so it
/// is O(depth × clippingAncestors). [resolveOcclusionGeometry] computes the same
/// result in O(depth) and should be preferred on per-frame paths.
Rect? calculateEffectiveClip(RenderBox node) {
  Rect? accumulatedClip;
  RenderObject? child = node;
  RenderObject? ancestor = node.parent;

  while (ancestor != null) {
    if (ancestor is RenderBox) {
      final clip = ancestor.describeApproximatePaintClip(child!);
      if (clip != null) {
        final transform = ancestor.getTransformTo(null);
        final globalClip = MatrixUtils.transformRect(transform, clip);
        accumulatedClip = accumulatedClip?.intersect(globalClip) ?? globalClip;
      }
    }
    child = ancestor;
    ancestor = ancestor.parent;
  }

  return accumulatedClip;
}
