import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';

/// Coherence is a property of the *capture*, not the platform. When Flutter
/// itself rasterises the pixels (`requestSceneFrame` with pixels), the rects are
/// resolved from the same committed frame `rootLayer.toImage()` captures, so a
/// served rect is not an estimate of where the field was a sampling interval ago:
/// it is where the field is in the pixels being captured. For that capture — and
/// only that capture — the sliding window, the motion margin and the detach grace
/// are switched off, and every one of those absences is asserted below, because a
/// silent reintroduction would cost the coherence without failing anything else.
///
/// A native-screenshot capture (`requestAllOcclusionRects`, or a scene frame
/// Flutter supplied no pixels for) screenshots a hop later, so it keeps the full
/// widening pipeline; that path is `getOcclusionRects()` here and is covered by
/// the rest of the suite. The current iOS SDK screenshots natively, so it takes
/// that path today.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;

  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  /// A coherent serve — what a `requestSceneFrame` capture whose pixels Flutter
  /// rasterised receives.
  List<Rect> served(WidgetTester tester) {
    final dpr = tester.view.devicePixelRatio;
    return registry
        .debugServeRects(coherent: true)
        .map((r) => Rect.fromLTRB(
              (r['left'] as double) / dpr,
              (r['top'] as double) / dpr,
              (r['right'] as double) / dpr,
              (r['bottom'] as double) / dpr,
            ))
        .toList();
  }

  /// The on-screen rect of each mounted field, resolved the same way the
  /// adapter does — clipped to the viewport, since a served rect is clipped by
  /// its ancestors and a field hanging off the bottom of the list is only
  /// partly visible.
  List<Rect> fieldRects(WidgetTester tester) {
    final screen =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    final rects = <Rect>[];
    for (final element in find.byType(TextField).evaluate()) {
      final box = element.renderObject as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final rect = MatrixUtils.transformRect(
          box.getTransformTo(null), Offset.zero & box.size);
      if (rect.isEmpty || !rect.overlaps(screen)) continue;
      rects.add(rect.intersect(screen));
    }
    return rects;
  }

  Widget form({int count = 1, ScrollController? controller}) => MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: TextEditingController(text: 'secret $i'),
                    decoration: InputDecoration(labelText: 'Field $i'),
                  ),
                ),
            ],
          ),
        ),
      );

  testWidgets('a coherent capture discovers even if no frame ran discovery first',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();

    // Discovery runs inside the capture as well as on frames, so the capture is
    // always an authority on what is on screen — it masks its own frame.
    expect(served(tester), hasLength(1));
    expect(registry.debugTextFieldStore.adapterCount, 1);
  });

  testWidgets('a coherent serve is the field exactly — no margin, no union',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();

    final masks = served(tester);
    final fields = fieldRects(tester);
    expect(masks, hasLength(1));
    expect(fields, hasLength(1));

    // The decorator box is what gets masked, so the mask covers the field and
    // is not wildly larger than it. Equality to within a pixel on every edge is
    // the assertion that no margin was applied.
    final mask = masks.single;
    final field = fields.single;
    expect(mask.left, lessThanOrEqualTo(field.left + 0.01));
    expect(mask.top, lessThanOrEqualTo(field.top + 0.01));
    expect(mask.right, greaterThanOrEqualTo(field.right - 0.01));
    expect(mask.bottom, greaterThanOrEqualTo(field.bottom - 0.01));
    expect(mask.width, lessThan(field.width + 1),
        reason: 'a motion margin or window union would inflate this');
    expect(mask.height, lessThan(field.height + 1),
        reason: 'a motion margin or window union would inflate this');
  });

  testWidgets('a field mid-scroll is served where it is, not where it was',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(form(count: 12, controller: controller));
    await tester.pumpAndSettle();

    // Establish a position, capture it, then move without giving the frame
    // pipeline any chance to resample.
    expect(served(tester), isNotEmpty);
    final before = served(tester).first;

    controller.jumpTo(140);
    await tester.pump();

    final after = served(tester);
    final fields = fieldRects(tester);
    expect(after.first, isNot(equals(before)),
        reason:
            'the served rect must follow the scroll within the same capture');

    // Every visible field is covered, and no mask spans the distance travelled —
    // which a union of before/after positions would.
    for (final field in fields) {
      final covered = after.any((m) =>
          m.left <= field.left + 0.01 &&
          m.top <= field.top + 0.01 &&
          m.right >= field.right - 0.01 &&
          m.bottom >= field.bottom - 0.01);
      expect(covered, isTrue, reason: 'field $field uncovered. Served: $after');
    }
    for (final m in after) {
      expect(m.height, lessThan(140),
          reason: 'mask $m spans the scroll distance — that is a union of two '
              'positions, which a coherent serve must never produce');
    }
  });

  testWidgets('a removed field stops being served immediately — no grace',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();
    expect(served(tester), hasLength(1));

    // The field leaves the tree, so it leaves the pixels too. A grace ghost
    // here would mask a region the captured frame no longer shows.
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('no fields here')))));
    await tester.pumpAndSettle();

    expect(served(tester), isEmpty,
        reason: 'detach grace covers a native-screenshot capture racing a '
            'detach; a coherent serve rasterises the same frame it scans, so '
            'there is no race to cover');
  });

  testWidgets('disabling still clears immediately', (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();
    expect(served(tester), hasLength(1));

    registry.occludeAllTextFields = false;
    expect(served(tester), isEmpty);
  });
}
