import 'package:flutter/rendering.dart';

/// Geometry shared by every occlusion-reporting render box.

typedef VisibilityChecker = bool Function(
    RenderObject ancestor, RenderObject child);

/// Ancestor render-object types that need a bespoke visibility rule beyond the
/// generic `paintsChild` check.
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
  /// to `node.getTransformTo(null)`.
  final Matrix4 transform;

  /// Accumulated ancestor paint clip in global coordinates, or `null` when
  /// nothing clips the node.
  final Rect? clip;
}

/// Scratch buffer for the ancestor chain, reused across calls to avoid an
/// allocation per field per frame. Safe because resolution is synchronous and
/// single-threaded — there is never a second traversal in flight.
final List<RenderObject> _chainBuffer = <RenderObject>[];

/// Resolves visibility, global transform and effective clip in one pass over the
/// ancestor chain, replacing three separate traversals — one of which called
/// `getTransformTo` per clipping ancestor, making it O(depth × clips) alone.
///
/// Walking the collected chain root-to-leaf, the accumulated matrix maps the
/// current ancestor's local space to global, which is the frame its clip rect is
/// already in — so clips globalise without a second traversal.
///
/// A `RenderEditable` sits ~63 ancestors deep and this runs per field per frame.
OcclusionGeometry resolveOcclusionGeometry(RenderBox node) {
  _chainBuffer.clear();
  _chainBuffer.add(node);

  var isVisible = true;
  RenderObject child = node;
  RenderObject? ancestor = node.parent;

  // Upward pass: collect the chain and evaluate visibility. The chain is
  // collected in full even once visibility is known to be false, because callers
  // that pass `skipVisibilityCheck` still need the transform.
  while (ancestor != null) {
    if (isVisible) {
      if (!ancestor.paintsChild(child)) {
        isVisible = false;
      } else {
        final checker = _visibilityCheckers[ancestor.runtimeType];
        if (checker != null && !checker(ancestor, child)) {
          isVisible = false;
        }
      }
    }
    _chainBuffer.add(ancestor);
    child = ancestor;
    ancestor = ancestor.parent;
  }

  // Downward pass: root to leaf, accumulating the paint transform and clipping.
  final transform = Matrix4.identity();
  Rect? clip;
  final rootIndex = _chainBuffer.length - 1;

  for (var i = rootIndex; i > 0; i--) {
    final parent = _chainBuffer[i];
    final kid = _chainBuffer[i - 1];

    // `transform` currently maps parent-local -> target space, which is exactly
    // the frame the clip below is expressed in, so globalise it BEFORE composing
    // parent's transform for kid.
    if (parent is RenderBox) {
      final localClip = parent.describeApproximatePaintClip(kid);
      if (localClip != null) {
        final globalClip = MatrixUtils.transformRect(transform, localClip);
        clip = clip?.intersect(globalClip) ?? globalClip;
      }
    }

    // The root's own paint transform is deliberately NOT applied. Flutter's
    // `getTransformTo(null)` stops one short of the root (`lastIndex =
    // length - 2`), so its result is in the root child's coordinate space —
    // logical pixels — not the root's device-pixel space. Applying `RenderView`'s
    // transform here would scale every rect by the device pixel ratio, putting
    // every mask at 3× its true position on a 3× screen.
    if (i < rootIndex) {
      parent.applyPaintTransform(kid, transform);
    }
  }

  return OcclusionGeometry(
      isVisible: isVisible, transform: transform, clip: clip);
}
