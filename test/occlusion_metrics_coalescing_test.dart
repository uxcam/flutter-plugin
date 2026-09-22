import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// A keyboard animation delivers a metrics change on every frame it runs.
/// Re-arming four forced discovery walks on each one — and letting every
/// discovery frame refresh every field's bounds — made both tiers run at full
/// frame rate for the whole animation, which is the burst behind the worst
/// frames QA measured. Now an episode arms discovery once, every event still
/// clears the windows (that is what keeps the unknown-velocity inflate armed
/// while the fields slide), and a discovery frame resolves only the adapters it
/// creates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  late int now;
  late TextFieldRectStore store;
  void driveClock() {
    now = 0;
    registry.debugSetClock(() => now);
    store = TextFieldRectStore(clock: () => now);
    registry.debugReplaceTextFieldStore(store);
  }

  Future<void> frame(WidgetTester tester, {int ms = 16}) async {
    now += ms;
    tester.binding.scheduleFrame();
    await tester.pump(Duration(milliseconds: ms));
  }

  Rect servedRect(WidgetTester tester) {
    final dpr = tester.view.devicePixelRatio;
    final rects = registry.getOcclusionRects();
    expect(rects, isNotEmpty);
    final r = rects.first;
    return Rect.fromLTRB(
      (r['left'] as double) / dpr,
      (r['top'] as double) / dpr,
      (r['right'] as double) / dpr,
      (r['bottom'] as double) / dpr,
    );
  }

  Rect firstFieldRect(WidgetTester tester) {
    final box =
        find.byType(TextField).evaluate().first.renderObject as RenderBox;
    return MatrixUtils.transformRect(
        box.getTransformTo(null), Offset.zero & box.size);
  }

  Widget form({int count = 1}) => MaterialApp(
        home: Scaffold(
          body: ListView(
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

  testWidgets(
      'a burst of metrics changes arms discovery once, clears every event, '
      'and keeps the field inflated throughout', (tester) async {
    driveClock();
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    // Establish the native-screenshot regime and let the field settle with a
    // full history, so the inflate below can only come from the clears.
    registry.getOcclusionRects();
    for (var i = 0; i < 12; i++) {
      await frame(tester);
    }
    now += 200;
    final field = firstFieldRect(tester);
    final settled = servedRect(tester);
    expect(settled.width, lessThan(field.width + 40),
        reason: 'a settled field is served tight');

    registry.debugForcedArmCount = 0;
    registry.debugDiscoveryWalkCount = 0;
    registry.debugWindowClearCount = 0;

    // Fifteen frames of keyboard animation, a metrics change on each. Captures
    // are taken at three points only — every capture runs its own discovery
    // walk by design, so serving on every frame would hide the frame-driven
    // count this test is about.
    const events = 15;
    var captures = 0;
    for (var i = 0; i < events; i++) {
      registry.didChangeMetrics();
      await frame(tester);
      if (i % 7 == 0) {
        captures++;
        final mid = servedRect(tester);
        expect(mid.width, greaterThan(settled.width + 200),
            reason: 'frame $i of the episode must be served inflated');
      }
    }

    expect(registry.debugForcedArmCount, 1,
        reason: 'discovery is armed once per episode, not once per event');
    expect(registry.debugWindowClearCount, events,
        reason: 'every event clears the windows — the clear re-arms the inflate');
    final frameWalks = registry.debugDiscoveryWalkCount - captures;
    expect(frameWalks, lessThanOrEqualTo(10),
        reason: 'four forced frames plus the 48 ms cadence over 240 ms, not '
            'a walk on every frame of the animation');
    expect(frameWalks, greaterThanOrEqualTo(2),
        reason: 'the episode still arms forced discovery once');

    // After the episode the inflate withdraws and the mask is tight again.
    now += 600;
    await frame(tester);
    final after = servedRect(tester);
    expect(after.width, lessThan(field.width + 40));
  });

  testWidgets('a discovery frame resolves only the adapters it creates',
      (tester) async {
    driveClock();
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form(count: 6));
    registry.getOcclusionRects();
    for (var i = 0; i < 6; i++) {
      await frame(tester);
    }

    // A forced discovery on a frame inside the bounds cadence: every field is
    // already known, so nothing is resolved.
    registry.currentScreenName = 'Checkout';
    final before = store.debugBoundsResolveCount;
    await frame(tester, ms: 8);
    expect(store.debugBoundsResolveCount, before,
        reason: 'known fields keep to the 33 ms cadence even on a discovery '
            'frame');

    // One more field appears. The frame that mounts it is a forced-discovery
    // frame, so it is discovered — and resolved — right there: exactly one
    // resolve, for the new adapter alone, on that frame and the next.
    final beforeNew = store.debugBoundsResolveCount;
    await tester.pumpWidget(form(count: 7));
    await frame(tester, ms: 8);
    expect(store.debugBoundsResolveCount - beforeNew, 1,
        reason: 'the new field is resolved on creation; the six known fields '
            'are not');
    expect(registry.getOcclusionRects().length, greaterThanOrEqualTo(7));
  });
}
