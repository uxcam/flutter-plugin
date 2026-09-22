import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// A metrics change — keyboard show/hide, rotation — wipes every field's velocity
/// history (`didChangeMetrics` → `clearSlidingWindows`) at the very instant the
/// viewport starts resizing and the fields start sliding. A field that already
/// existed is not *young*, so the unknown-velocity inflate that protects a
/// freshly-appeared field would never apply to it, and with its window empty the
/// motion margin cannot be computed either — leaving it a couple of frames of
/// exposure on a native-screenshot capture while the window re-accumulates.
///
/// Clearing the window therefore stamps the field as unknown-velocity for
/// [_settleWindowMs], exactly as adapter creation does, so the blanket inflate
/// covers the re-acquisition and then withdraws on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  // Mirrors `TextFieldOccludeRenderBox._unknownVelocityWindowMs`.
  const settleWindowMs = 150;

  late int now;
  void driveClock() {
    now = 0;
    registry.debugSetClock(() => now);
    registry.debugReplaceTextFieldStore(TextFieldRectStore(clock: () => now));
  }

  /// A native-screenshot serve — the path that needs the inflate.
  Rect servedRect(WidgetTester tester) {
    final dpr = tester.view.devicePixelRatio;
    final rects = registry.getOcclusionRects();
    expect(rects, hasLength(1), reason: 'exactly one field is on screen');
    final r = rects.single;
    return Rect.fromLTRB(
      (r['left'] as double) / dpr,
      (r['top'] as double) / dpr,
      (r['right'] as double) / dpr,
      (r['bottom'] as double) / dpr,
    );
  }

  Rect fieldRect(WidgetTester tester) {
    final box = find.byType(TextField).evaluate().single.renderObject as RenderBox;
    return MatrixUtils.transformRect(
        box.getTransformTo(null), Offset.zero & box.size);
  }

  Widget form() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: TextEditingController(text: 'secret'),
                decoration: const InputDecoration(labelText: 'Field'),
              ),
            ),
          ),
        ),
      );

  testWidgets(
      'a pre-existing field stays over-masked through a metrics-change clear',
      (tester) async {
    driveClock();
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());

    // Establish the native-screenshot regime: the frame pipeline only samples
    // once a capture has asked for rects to screenshot natively, and that first
    // capture is served inflated because no history exists yet.
    registry.getOcclusionRects();

    // Age the adapter well past the settle window and fill its sliding window, so
    // nothing but a fresh clear can put it back into the unknown-velocity state.
    for (var i = 0; i < 12; i++) {
      now += 16;
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(now, greaterThan(settleWindowMs));

    final field = fieldRect(tester);
    final settled = servedRect(tester);
    // Static field, full velocity history → a tight mask, no inflate.
    expect(settled.width, lessThan(field.width + 40),
        reason: 'a settled field must not be inflated: $settled vs $field');

    // The keyboard begins to appear: the metrics change wipes the window.
    registry.debugTextFieldStore.clearSlidingWindows();

    // The first capture after the clear, one frame later. The field has no
    // velocity history, but it is about to slide — so it must be inflated, not
    // served tight where a native screenshot a hop later would expose it.
    now += 16;
    final afterClear = servedRect(tester);
    expect(afterClear.width, greaterThan(settled.width + 200),
        reason: 'the clear must re-arm the unknown-velocity inflate: '
            '$afterClear vs settled $settled');
    expect(
      afterClear.left <= field.left &&
          afterClear.top <= field.top &&
          afterClear.right >= field.right &&
          afterClear.bottom >= field.bottom,
      isTrue,
      reason: 'the inflated mask must still cover the field: $afterClear vs $field',
    );

    // Once the settle window has elapsed the inflate withdraws and the mask is
    // tight again — the over-mask does not outlive the re-acquisition.
    now += settleWindowMs + 16;
    final reSettled = servedRect(tester);
    expect(reSettled.width, lessThan(afterClear.width - 200),
        reason: 'the inflate must withdraw after the settle window: '
            '$reSettled vs $afterClear');
  });
}
