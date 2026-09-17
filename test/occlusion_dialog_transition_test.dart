import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// A text field inside a dialog must be masked on every frame the dialog is
/// visible — not only once it has settled.
///
/// Two defects made it lag. Discovery is throttled to 48 ms and a dialog push
/// changes no screen name, so nothing armed a forced scan and the field went
/// unmasked for the first three frames. And the motion margin derived the whole
/// rect's velocity from its top-left corner, which models translation only — a
/// dialog scaling in has left/top and right/bottom travelling in opposite
/// directions, so the advancing edges were never extended and stayed exposed for
/// the entire transition.
/// Mirrors `OcclusionRegistry._forceDiscoveryFrameCount`.
const _forceDiscoveryFrameCount = 4;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  /// The cadences are in real milliseconds while `pump` advances only the test
  /// clock, so drive both together — otherwise no wall time passes, the discovery
  /// throttle never opens and the velocity window never gains a second sample.
  ({Future<void> Function() step, Future<void> Function() settleDiscovery})
      driveClock(WidgetTester tester) {
    var now = 0;
    registry.debugSetClock(() => now);
    registry.debugReplaceTextFieldStore(TextFieldRectStore(clock: () => now));
    return (
      step: () async {
        now += 16;
        await tester.pump(const Duration(milliseconds: 16));
      },
      // Leaves the discovery throttle CLOSED and no forced scan owed, so whether
      // a field appearing on the next frame gets masked depends solely on
      // something arming a forced scan for it.
      //
      // `tester.pump` only produces a frame when one is already scheduled, and a
      // settled tree schedules none — so the forced-discovery frames armed by
      // enabling the feature would otherwise still be owed here. Schedule the
      // frames explicitly to burn them off, in 1 ms steps so the throttle window
      // ends up recent rather than expired.
      settleDiscovery: () async {
        for (var i = 0; i < _forceDiscoveryFrameCount + 2; i++) {
          now += 1;
          tester.binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 1));
        }
      },
    );
  }

  Widget app({required void Function(BuildContext) onPressed}) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

  /// Rects come back in device pixels (the Android/web wire format), while
  /// `tester.getRect` is logical — undo the scaling rather than overriding the
  /// device pixel ratio, which would fire `didChangeMetrics` and perturb the very
  /// discovery timing under test.
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

  Rect? fieldRect(WidgetTester tester) {
    final finder = find.byType(TextField);
    return finder.evaluate().isEmpty ? null : tester.getRect(finder);
  }

  testWidgets('a dialog field is masked on the first frame it is visible',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(app(
      onPressed: (context) => unawaited(showGeneralDialog<void>(
        context: context,
        transitionDuration: Duration.zero, // opaque immediately
        pageBuilder: (_, __, ___) => const AlertDialog(content: TextField()),
      )),
    ));
    // Settle well past the discovery throttle so nothing is owed a forced scan.
    for (var i = 0; i < 20; i++) {
      await clock.step();
    }
    expect(served(tester), isEmpty, reason: 'no field on screen yet');

    await clock.settleDiscovery();
    await tester.tap(find.text('open'));
    await clock.step();

    final field = fieldRect(tester)!;
    expect(served(tester), hasLength(1),
        reason: 'the dialog is fully opaque on this frame, so waiting for the '
            '48 ms discovery throttle would leak it');
    expect(served(tester).single.contains(field.topLeft), isTrue);
    expect(
        served(tester).single.contains(field.bottomRight - const Offset(1, 1)),
        isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('the mask covers a scaling dialog field on every frame',
      (tester) async {
    final clock = driveClock(tester);
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(app(
      onPressed: (context) => unawaited(showGeneralDialog<void>(
        context: context,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const AlertDialog(content: TextField()),
        transitionBuilder: (_, animation, __, child) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
      )),
    ));
    for (var i = 0; i < 20; i++) {
      await clock.step();
    }

    await tester.tap(find.text('open'));

    var framesChecked = 0;
    for (var frame = 0; frame < 20; frame++) {
      await clock.step();

      final field = fieldRect(tester);
      if (field == null || field.isEmpty) continue; // scale 0: nothing painted
      framesChecked++;

      final rects = served(tester);
      expect(rects, hasLength(1),
          reason: 'frame $frame: field at $field is visible and unmasked');
      final mask = rects.single;
      expect(mask.contains(field.topLeft), isTrue,
          reason: 'frame $frame: mask $mask misses the leading top-left of '
              '$field');
      expect(
          mask.contains(field.bottomRight - const Offset(0.01, 0.01)), isTrue,
          reason: 'frame $frame: mask $mask misses the leading bottom-right of '
              '$field — the growing edge the corner-derived velocity ignored');
    }

    expect(framesChecked, greaterThan(10),
        reason: 'the transition must actually have been sampled');

    await tester.pumpAndSettle();
  });
}
