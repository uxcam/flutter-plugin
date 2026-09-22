import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_geometry.dart';

import 'occlusion_geometry_reference.dart';

/// A geometry pass memoises each ancestor's resolved state so the fields of one
/// screen — which share almost their entire chain — cost O(unique ancestors)
/// instead of O(fields × depth). The memo is exact because a tree has one path
/// from the root to any node, so an ancestor's transform, clip and visibility are
/// the same whichever descendant asks. Both halves are pinned here: the answers
/// inside a pass match the reference traversals field for field, and the work
/// count shrinks the way the design says it must.
void main() {
  RenderBox boxOf(Element element) => element.renderObject! as RenderBox;

  void expectMatchesReference(RenderBox box, OcclusionGeometry resolved,
      {required String at}) {
    expect(resolved.transform.storage, box.getTransformTo(null).storage,
        reason: 'transform diverged at $at');
    final expectedClip = calculateEffectiveClip(box);
    if (expectedClip == null) {
      expect(resolved.clip, isNull, reason: 'spurious clip at $at');
    } else {
      expect(resolved.clip, isNotNull, reason: 'missing clip at $at');
      expect(resolved.clip!.left, closeTo(expectedClip.left, 0.01),
          reason: 'clip.left at $at');
      expect(resolved.clip!.top, closeTo(expectedClip.top, 0.01),
          reason: 'clip.top at $at');
      expect(resolved.clip!.right, closeTo(expectedClip.right, 0.01),
          reason: 'clip.right at $at');
      expect(resolved.clip!.bottom, closeTo(expectedClip.bottom, 0.01),
          reason: 'clip.bottom at $at');
    }
    expect(resolved.isVisible, !isRenderObjectEffectivelyInvisible(box),
        reason: 'visibility at $at');
  }

  /// Fields under nested transforms and clips inside a scrolled list, some of
  /// them inside a hidden `IndexedStack` branch — every ingredient the memo has
  /// to carry from a shared ancestor down to each field.
  Widget fixture(ScrollController controller) => MaterialApp(
        home: Scaffold(
          body: Transform.translate(
            offset: const Offset(7, 11),
            child: ClipRect(
              child: ListView(
                controller: controller,
                children: [
                  for (var i = 0; i < 12; i++)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: i % 4 == 3
                          ? IndexedStack(
                              index: 0,
                              children: [
                                const Text('shown'),
                                TextField(
                                  controller: TextEditingController(
                                      text: 'hidden $i'),
                                ),
                              ],
                            )
                          : Transform.scale(
                              scale: i.isEven ? 1.0 : 0.9,
                              child: TextField(
                                controller:
                                    TextEditingController(text: 'field $i'),
                                decoration: InputDecoration(
                                    labelText: 'Field $i',
                                    border: const OutlineInputBorder()),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('inside a pass every field matches the reference traversals',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(fixture(controller));
    controller.jumpTo(95);
    await tester.pump();

    final fields = find.byType(TextField).evaluate().toList();
    expect(fields.length, greaterThanOrEqualTo(6));

    beginGeometryPass();
    try {
      for (final element in fields) {
        final box = boxOf(element);
        expectMatchesReference(box, resolveOcclusionGeometry(box),
            at: 'field ${fields.indexOf(element)} (in pass)');
      }
      // The same field asked twice in one pass is a pure memo hit and must give
      // the same answer.
      final box = boxOf(fields.first);
      final again = resolveOcclusionGeometry(box);
      expectMatchesReference(box, again, at: 'repeat lookup');
    } finally {
      endGeometryPass();
    }
    expect(debugPassCacheSize, 0, reason: 'a closed pass keeps nothing');
  });

  testWidgets('a pass resolves shared ancestors once', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(fixture(controller));
    await tester.pump();

    final boxes = find.byType(TextField).evaluate().map(boxOf).toList();
    expect(boxes.length, greaterThanOrEqualTo(6));

    // One field alone: its whole chain.
    debugEdgesComputed = 0;
    beginGeometryPass();
    try {
      resolveOcclusionGeometry(boxes.first);
    } finally {
      endGeometryPass();
    }
    final oneField = debugEdgesComputed;
    expect(oneField, greaterThan(30),
        reason: 'a TextField in a Material list is dozens of ancestors deep');

    // Every field in one pass: the shared chain once, plus each field's own
    // short suffix below the list.
    debugEdgesComputed = 0;
    beginGeometryPass();
    try {
      for (final box in boxes) {
        resolveOcclusionGeometry(box);
      }
    } finally {
      endGeometryPass();
    }
    final allFields = debugEdgesComputed;

    expect(allFields, lessThan(oneField + boxes.length * 25),
        reason: '${boxes.length} fields cost $allFields edges against '
            '$oneField for one — the shared chain is being re-walked');
    expect(allFields, lessThan(boxes.length * oneField ~/ 2),
        reason: 'the pass must save more than half of the per-field walks');

    // Without a pass each call pays its full chain again.
    debugEdgesComputed = 0;
    for (final box in boxes) {
      resolveOcclusionGeometry(box);
    }
    expect(debugEdgesComputed, greaterThanOrEqualTo(boxes.length * oneField),
        reason: 'outside a pass nothing may be remembered between calls');
  });

  testWidgets('nothing survives a pass, so a layout change is never served stale',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(fixture(controller));
    await tester.pump();

    final box = boxOf(find.byType(TextField).evaluate().first);
    beginGeometryPass();
    final before = resolveOcclusionGeometry(box).transform.clone();
    endGeometryPass();
    expect(debugPassCacheSize, 0);

    controller.jumpTo(60);
    await tester.pump();

    beginGeometryPass();
    try {
      final after = resolveOcclusionGeometry(box);
      expect(after.transform.storage, isNot(equals(before.storage)),
          reason: 'the field moved, so its transform must move with it');
      expectMatchesReference(box, after, at: 'after scroll');
    } finally {
      endGeometryPass();
    }
  });

  testWidgets('nested passes share one memo and close together',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(fixture(controller));
    await tester.pump();

    final boxes = find.byType(TextField).evaluate().map(boxOf).toList();
    beginGeometryPass();
    resolveOcclusionGeometry(boxes.first);
    final outer = debugPassCacheSize;
    beginGeometryPass();
    resolveOcclusionGeometry(boxes.last);
    expect(debugPassCacheSize, greaterThan(outer),
        reason: 'the inner pass adds to the outer memo rather than replacing it');
    endGeometryPass();
    expect(debugPassCacheSize, greaterThan(0),
        reason: 'closing the inner pass must keep the outer memo alive');
    endGeometryPass();
    expect(debugPassCacheSize, 0);
  });
}
