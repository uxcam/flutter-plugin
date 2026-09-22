import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/internal/motion_reporter.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// The frame pipeline runs only while a native-screenshot capture is possible.
///
/// Every capture discovers and re-resolves before answering, so what a capture
/// masks never depends on the frame pipeline; a *coherent* capture — a scene
/// frame Flutter rasterised itself — reads none of the pipeline's history either.
/// So while captures are coherent the pipeline is dead weight, and the registry
/// gates it to detach bookkeeping. The gate opens the instant a native-screenshot
/// capture becomes possible (keyboard up, metrics settling, or native asking for
/// rects without pixels) and that transition re-arms the unknown-velocity inflate,
/// so the first widened serve is over-masked rather than served tight with no
/// history behind it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  /// Drives the registry's cadences, which are in real milliseconds while `pump`
  /// advances only the test clock. `settle` schedules frames explicitly — a
  /// settled tree schedules none.
  ({Future<void> Function() settle, void Function(int) advance}) driveClock(
      WidgetTester tester) {
    var now = 0;
    registry.debugSetClock(() => now);
    registry.debugReplaceTextFieldStore(TextFieldRectStore(clock: () => now));
    return (
      settle: () async {
        for (var i = 0; i < 8; i++) {
          now += 16;
          tester.binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
      advance: (int ms) => now += ms,
    );
  }

  Future<dynamic> send(WidgetTester tester, MethodCall call) async {
    final data =
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter_uxcam',
      const StandardMethodCodec().encodeMethodCall(call),
      null,
    );
    // A capture request arms the motion reporter's idle timer, which is not
    // what these tests are about.
    MotionReporter.instance.debugReset();
    return const StandardMethodCodec().decodeEnvelope(data!);
  }

  Rect rectOf(Map<dynamic, dynamic> r, double dpr) => Rect.fromLTRB(
        (r['left'] as double) / dpr,
        (r['top'] as double) / dpr,
        (r['right'] as double) / dpr,
        (r['bottom'] as double) / dpr,
      );

  Rect fieldRect(WidgetTester tester) {
    final box =
        find.byType(TextField).evaluate().single.renderObject as RenderBox;
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

  testWidgets('while every capture is coherent the pipeline stays gated',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form(count: 6));
    await clock.settle();

    expect(registry.debugPipelineActive, isFalse);
    expect(registry.debugPipelineFrameCount, 0,
        reason: 'no capture has asked for a native screenshot, so nothing the '
            'pipeline produces would ever be read');
    expect(registry.debugGatedFrameCount, greaterThan(0));

    // A coherent capture still masks every field — it discovers and resolves
    // inside the capture, which is exactly why the pipeline is not needed.
    final served = registry.debugServeRects(coherent: true);
    expect(served, hasLength(6));
    expect(registry.debugPipelineActive, isFalse,
        reason: 'a coherent capture must not open the gate');

    await clock.settle();
    expect(registry.debugPipelineFrameCount, 0);
  });

  testWidgets(
      'a native-screenshot capture opens the gate and is served inflated',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await clock.settle();
    // Well past the adapter's unknown-velocity window, so only the gate
    // transition itself can re-arm the inflate.
    clock.advance(400);
    await clock.settle();
    expect(registry.debugPipelineActive, isFalse);

    // `getOcclusionRects` is what `requestAllOcclusionRects` serves: rects for
    // a screenshot taken natively a hop later.
    final dpr = tester.view.devicePixelRatio;
    final served = registry.getOcclusionRects();
    expect(served, hasLength(1));
    final mask = rectOf(served.single, dpr);
    final field = fieldRect(tester);

    expect(registry.debugPipelineActive, isTrue);
    expect(mask.width, greaterThan(field.width + 200),
        reason: 'no history exists yet, so the serve must be inflated: '
            '$mask vs $field');
    expect(
      mask.left <= field.left &&
          mask.top <= field.top &&
          mask.right >= field.right &&
          mask.bottom >= field.bottom,
      isTrue,
      reason: 'the inflated mask must still cover the field',
    );

    // From here the pipeline runs on every frame and history accumulates.
    final before = registry.debugPipelineFrameCount;
    await clock.settle();
    expect(registry.debugPipelineFrameCount, greaterThan(before));

    // Once history exists the inflate withdraws and the mask tightens.
    clock.advance(200);
    final tight = rectOf(registry.getOcclusionRects().single, dpr);
    expect(tight.width, lessThan(mask.width - 200),
        reason: 'with a sampled window the serve must not stay inflated');
  });

  testWidgets(
      'a scene frame native could not take pixels for opens the gate too',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await clock.settle();
    expect(registry.debugPipelineActive, isFalse);

    // `includePixels: false` is how native says the scene path is vetoed
    // (keyboard, webview, presented controller) and it will screenshot instead.
    final response = await send(
        tester,
        const MethodCall('requestSceneFrame',
            {'includePixels': false, 'occludeAllTextFields': true})) as Map;

    expect(response['rects'], hasLength(1));
    expect(registry.debugPipelineActive, isTrue);
  });

  testWidgets('a coherent capture closes the gate again', (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await clock.settle();

    registry.getOcclusionRects();
    expect(registry.debugPipelineActive, isTrue);
    await clock.settle();
    final ran = registry.debugPipelineFrameCount;
    expect(ran, greaterThan(0));

    // Native is back on the scene path: this capture is coherent.
    registry.debugServeRects(coherent: true);
    expect(registry.debugPipelineActive, isFalse,
        reason: 'native decides the regime per capture; a coherent capture '
            'means the pipeline has nothing left to feed');

    await clock.settle();
    expect(registry.debugPipelineFrameCount, ran,
        reason: 'no pipeline frame may run while the gate is closed');
  });

  testWidgets('the keyboard opens the gate on the frame it appears',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await clock.settle();
    expect(registry.debugPipelineActive, isFalse);

    // The keyboard starts to rise: view insets change, which is a metrics
    // change Dart sees on this very frame.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(registry.debugPipelineActive, isTrue);

    // The 500 ms settle window passes, but the keyboard is still up.
    clock.advance(600);
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(registry.debugPipelineActive, isTrue,
        reason: 'a native screenshot is possible for as long as the keyboard '
            'is up, whatever the metrics timer says');

    // Keyboard down, metrics settled, no native-screenshot capture seen: the
    // next frame closes the gate.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    clock.advance(600);
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(registry.debugPipelineActive, isFalse);
  });

  testWidgets('screen and focus changes wake the engine only while active',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Gate closed: a screen change arms discovery for the capture path but
    // must not wake a settled screen.
    registry.currentScreenName = 'Checkout';
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(registry.debugServeRects(coherent: true), hasLength(1),
        reason: 'the capture still discovers on its own');

    // Gate open: the pipeline needs the frame to run on.
    registry.getOcclusionRects();
    await tester.pumpAndSettle();
    registry.currentScreenName = 'Payment';
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('detached adapters are pruned within a frame while gated',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();

    expect(registry.debugServeRects(coherent: true), hasLength(1));
    expect(registry.debugTextFieldStore.adapterCount, 1);
    expect(registry.debugPipelineActive, isFalse);

    // The field leaves the tree; the gated frame's detach bookkeeping must
    // release its adapter (and the render subtree it pins) right away rather
    // than holding it until the next capture.
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('no fields')))));
    expect(registry.debugTextFieldStore.adapterCount, 0);
  });
}
