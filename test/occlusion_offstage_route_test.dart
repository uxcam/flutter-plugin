import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// Nothing on a screen that has been pushed over may be masked on the screens
/// above it.
///
/// `Navigator` keeps every `maintainState` route mounted in its `Overlay`
/// beneath the top opaque one, so a pushed-over screen's fields and wrappers
/// stay attached and sized while the overlay's theater skips them for layout
/// and paint. The theater does not say so through `paintsChild`, so by the
/// render-tree rule alone the whole previous screen stayed "visible" at
/// whatever transform its exit transition left it — a third of the width off
/// to the left under a Cupertino slide (rects with negative coordinates),
/// exactly in place under a fade-upwards. Every field on it was served on every
/// deeper screen until the user came back; a wrapper's cached rect outlived the
/// layer-detach grace through the metrics freeze and resurfaced whenever the
/// keyboard moved on the deeper screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;

  /// The cadences are in real milliseconds while `pump` advances only the test
  /// clock, so both are driven together — a frozen clock never lets the
  /// sliding window or the discovery throttle move.
  var fakeNow = 500000;
  setUp(() {
    registry.resetTextFieldStateForTesting();
    fakeNow = 500000;
    registry.debugSetClock(() => fakeNow);
    registry
        .debugReplaceTextFieldStore(TextFieldRectStore(clock: () => fakeNow));
  });
  tearDown(registry.resetTextFieldStateForTesting);

  Future<void> step(WidgetTester tester) async {
    fakeNow += 16;
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Runs a route transition to completion, including the frame after it in
  /// which the overlay marks the new route opaque and sends the old one
  /// offstage.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0;
        i < 50 || (tester.binding.hasScheduledFrame && i < 200);
        i++) {
      await step(tester);
    }
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'the tree did not settle');
  }

  /// Rects come back in device pixels; `tester.getRect` is logical.
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

  bool covers(Rect mask, Rect target) =>
      mask.left <= target.left + 1 &&
      mask.top <= target.top + 1 &&
      mask.right >= target.right - 1 &&
      mask.bottom >= target.bottom - 1;

  Widget fieldPage(String label) => Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: TextField(
              key: ValueKey(label),
              controller: TextEditingController(text: 'secret-$label'),
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
            ),
          ),
        ),
      );

  Widget plainPage(String label) => Scaffold(body: Center(child: Text(label)));

  Route<void> slide(Widget page) =>
      CupertinoPageRoute<void>(builder: (_) => page);

  testWidgets(
      'a field on the screen beneath is not served once the push has settled',
      (tester) async {
    registry.occludeAllTextFields = true;
    final nav = GlobalKey<NavigatorState>();
    await tester
        .pumpWidget(MaterialApp(navigatorKey: nav, home: fieldPage('first')));
    await settle(tester);
    expect(served(tester), hasLength(1));

    // A Cupertino slide leaves the outgoing page a third of the width to the
    // left — still attached, still sized, still "painted" by the render-tree
    // rule — which is where the negative-coordinate rects came from.
    nav.currentState!.push(slide(fieldPage('second')));
    await settle(tester);

    final rects = served(tester);
    expect(rects, hasLength(1),
        reason: 'only the field on the current screen may be served; the '
            'first screen is offstage beneath it: $rects');
    expect(
        covers(
            rects.single, tester.getRect(find.byKey(const ValueKey('second')))),
        isTrue,
        reason: 'the one rect must be the current screen\'s field');
  });

  testWidgets('nothing from the screens beneath reaches a deeper screen',
      (tester) async {
    registry.occludeAllTextFields = true;
    final nav = GlobalKey<NavigatorState>();
    await tester
        .pumpWidget(MaterialApp(navigatorKey: nav, home: fieldPage('first')));
    await settle(tester);

    nav.currentState!.push(slide(fieldPage('second')));
    await settle(tester);
    nav.currentState!.push(slide(plainPage('third')));
    await settle(tester);

    expect(served(tester), isEmpty,
        reason: 'two screens with fields sit beneath this one; neither is on '
            'screen');

    nav.currentState!.push(slide(fieldPage('fourth')));
    await settle(tester);
    final rects = served(tester);
    expect(rects, hasLength(1));
    expect(
        covers(
            rects.single, tester.getRect(find.byKey(const ValueKey('fourth')))),
        isTrue);
  });

  testWidgets(
      'popping back restores the mask, covering the field on every frame of '
      'the pop', (tester) async {
    registry.occludeAllTextFields = true;
    final nav = GlobalKey<NavigatorState>();
    await tester
        .pumpWidget(MaterialApp(navigatorKey: nav, home: fieldPage('first')));
    await settle(tester);
    nav.currentState!.push(slide(plainPage('second')));
    await settle(tester);
    expect(served(tester), isEmpty);

    nav.currentState!.pop();
    var framesChecked = 0;
    for (var frame = 0; frame < 40; frame++) {
      await step(tester);
      final finder = find.byKey(const ValueKey('first'));
      if (finder.evaluate().isEmpty) continue;
      final field = tester.getRect(finder);
      // Off the left edge entirely: nothing of it is on screen yet.
      if (field.right <= 0) continue;
      framesChecked++;
      final rects = served(tester);
      expect(rects.any((m) => covers(m, field)), isTrue,
          reason: 'frame $frame: the first screen is sliding back in with its '
              'field at $field, and nothing in $rects covers it');
    }
    expect(framesChecked, greaterThan(5),
        reason: 'the pop transition must actually have been sampled');

    await settle(tester);
    final rects = served(tester);
    expect(rects, hasLength(1));
    expect(
        covers(
            rects.single, tester.getRect(find.byKey(const ValueKey('first')))),
        isTrue);
  });

  testWidgets(
      'a wrapper on the screen beneath is not served — not even during a '
      'metrics freeze on the deeper screen', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(
        body: Center(
          child: OccludeWrapper(
            child: SizedBox(width: 200, height: 60, child: Text('wrapped')),
          ),
        ),
      ),
    ));
    await settle(tester);
    expect(served(tester), hasLength(1));

    nav.currentState!.push(slide(plainPage('second')));
    await settle(tester);
    expect(served(tester), isEmpty,
        reason: 'the wrapper is offstage beneath the current screen');

    // The keyboard moving on the deeper screen freezes wrapper occlusion to its
    // cached bounds. The cache must not hold the rect the wrapper had while it
    // was on screen.
    registry.didChangeMetrics();
    expect(served(tester), isEmpty,
        reason: 'the metrics freeze served the offstage wrapper\'s stale rect');
    fakeNow += 600; // let the freeze end
    await step(tester);

    nav.currentState!.pop();
    await settle(tester);
    final rects = served(tester);
    expect(rects, hasLength(1));
    expect(covers(rects.single, tester.getRect(find.byType(OccludeWrapper))),
        isTrue);
  });

  testWidgets('a screen beneath a non-opaque route stays masked',
      (tester) async {
    registry.occludeAllTextFields = true;
    final nav = GlobalKey<NavigatorState>();
    await tester
        .pumpWidget(MaterialApp(navigatorKey: nav, home: fieldPage('first')));
    await settle(tester);

    // A dialog's barrier is translucent, so the screen beneath is still on
    // stage — and still on screen, so its field stays masked.
    showDialog<void>(
      context: nav.currentContext!,
      builder: (_) => const AlertDialog(content: Text('hello')),
    );
    await settle(tester);

    final rects = served(tester);
    expect(rects, hasLength(1));
    expect(
        covers(
            rects.single, tester.getRect(find.byKey(const ValueKey('first')))),
        isTrue,
        reason: 'the field is visible behind the dialog');
  });

  testWidgets(
      'an in-place transition (fade-upwards) offstages the screen beneath too',
      (tester) async {
    registry.occludeAllTextFields = true;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        }),
      ),
      home: fieldPage('first'),
    ));
    await settle(tester);
    expect(served(tester), hasLength(1));

    // Fade-upwards leaves the outgoing page exactly where it was — no slide,
    // no fade — so nothing but the theater's skip says it is off screen.
    nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => plainPage('second')));
    await settle(tester);

    expect(served(tester), isEmpty,
        reason: 'the first screen sits in place beneath an opaque route');
  });
}
