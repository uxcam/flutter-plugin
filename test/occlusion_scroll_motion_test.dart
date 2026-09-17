import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// Every text field visible on screen must be covered by a served rect on every
/// frame — including while a list is flung, when fields build as they scroll in
/// and every field on screen is moving.
///
/// Two things left masks a full scroll step behind the fields during a fling:
/// the capture path served the stored bounds window rather than re-resolving
/// geometry, and it only ran discovery when a forced scan was already owed, so a
/// field that had just scrolled into view had no adapter at all and the only
/// rects on offer were the detach-grace ghosts of the items it replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  /// The cadences are in real milliseconds while `pump` advances only the test
  /// clock, so drive both together — otherwise no wall time passes and the
  /// throttles never open.
  ///
  /// `pump` also only produces a frame when one is already scheduled, and a
  /// settled tree schedules none, so the settle helper schedules them explicitly.
  ({
    Future<void> Function() step,
    Future<void> Function() settle,
    Future<void> Function() closeThrottles,
  }) driveClock(WidgetTester tester) {
    var now = 0;
    registry.debugSetClock(() => now);
    registry.debugReplaceTextFieldStore(TextFieldRectStore(clock: () => now));
    return (
      step: () async {
        now += 16;
        await tester.pump(const Duration(milliseconds: 16));
      },
      settle: () async {
        for (var i = 0; i < 8; i++) {
          now += 16;
          tester.binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
      // Runs a frame far enough ahead that BOTH the tier-1 bounds refresh (33 ms)
      // and tier-2 discovery (48 ms) are certain to happen on it, resetting both
      // windows to this instant — discovery forces a refresh too, so closing only
      // the bounds window is not enough. A following 16 ms frame is then certain
      // to do neither, leaving what a moving field gets entirely up to the
      // capture path.
      closeThrottles: () async {
        now += 48;
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 48));
      },
    );
  }

  List<Rect> served(WidgetTester tester) {
    final dpr = tester.view.devicePixelRatio;
    return registry
        .getOcclusionRects()
        .map((r) => Rect.fromLTRB(
              (r['left'] as double) / dpr,
              (r['top'] as double) / dpr,
              (r['right'] as double) / dpr,
              (r['bottom'] as double) / dpr,
            ))
        .toList();
  }

  /// The on-screen rect of every mounted field, through the paint transform —
  /// `localToGlobal(zero) & size` keeps the unscaled layout size and reports a
  /// rect far larger than reality for anything mid-scale.
  List<Rect> visibleFields(WidgetTester tester) {
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

  void expectEveryFieldCovered(WidgetTester tester, {required String at}) {
    final masks = served(tester);
    for (final field in visibleFields(tester)) {
      final covered = masks.any((m) =>
          m.left <= field.left + 0.01 &&
          m.top <= field.top + 0.01 &&
          m.right >= field.right - 0.01 &&
          m.bottom >= field.bottom - 0.01);
      expect(covered, isTrue,
          reason: '$at: field $field is on screen with no mask covering it. '
              'Served: $masks');
    }
  }

  testWidgets('every field stays covered through a hard fling', (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          itemCount: 60,
          itemExtent: 90,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: TextEditingController(text: 'secret $i'),
              decoration: InputDecoration(labelText: 'f$i'),
            ),
          ),
        ),
      ),
    ));
    await clock.settle();
    expectEveryFieldCovered(tester, at: 'settled');

    await tester.fling(find.byType(ListView), const Offset(0, -900), 9000);

    // The first frame after the gesture is the one that used to leak: every
    // field has jumped, and the fields scrolling in are brand new.
    for (var frame = 0; frame < 30; frame++) {
      await clock.step();
      expectEveryFieldCovered(tester, at: 'fling frame $frame');
    }

    await tester.pumpAndSettle();
    expectEveryFieldCovered(tester, at: 'after fling');
  });

  testWidgets('a field jumped back into view is covered on arrival',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;

    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 40),
            TextField(controller: TextEditingController(text: 'secret')),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    ));
    await clock.settle();

    // Far away, settled — the field is out of the viewport entirely.
    controller.jumpTo(1500);
    await clock.settle();
    expect(visibleFields(tester), isEmpty,
        reason: 'field should be off screen');

    // Back in one jump, at speed. Nothing arms a scan and the tier-1 refresh is
    // throttled out: no screen change, no metrics change, no focus change.
    await clock.closeThrottles();
    controller.jumpTo(0);
    await clock.step();

    expect(visibleFields(tester), isNotEmpty,
        reason: 'the field must be back on screen, or this asserts nothing');
    expectEveryFieldCovered(tester, at: 'jumped back into view');
    await tester.pumpAndSettle();
  });
}
