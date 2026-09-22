import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// The mask must cover the whole visible field, not just the glyphs.
///
/// A real device exposed `prefixText` to the left of the mask. Cause: the
/// decorator climb was capped at 6 ancestors while `_RenderDecoration` sits 11
/// above the `RenderEditable`, so every Material field fell back to the padded
/// glyph box — which covers the typed text but not the label, hint, prefix or
/// suffix, all of which the decorator paints outside it.
///
/// The counter-risk of raising the cap is over-masking: `ListTile` and `Chip` also
/// use `SlottedContainerRenderObjectMixin`, so a field inside one could resolve to
/// the whole row. Both directions are pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  /// Reported rects are physical pixels; the test view is 3× logical.
  List<Rect> masks() => registry.getOcclusionRects().map((r) {
        return Rect.fromLTRB(
          (r['left'] as double) / 3,
          (r['top'] as double) / 3,
          (r['right'] as double) / 3,
          (r['bottom'] as double) / 3,
        );
      }).toList();

  Rect boxOf(Finder finder, WidgetTester tester) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  bool covers(Rect mask, Rect target) =>
      mask.left <= target.left + 0.5 &&
      mask.top <= target.top + 0.5 &&
      mask.right >= target.right - 0.5 &&
      mask.bottom >= target.bottom - 0.5;

  testWidgets('mask covers label, hint and prefix, not just the glyphs',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextField(
            controller: TextEditingController(text: 'secret'),
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: '4111 1111 1111 1111',
              prefixText: 'AB-',
              suffixIcon: Icon(Icons.credit_card),
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),
    ));

    final field = boxOf(find.byType(TextField), tester);
    expect(masks().any((m) => covers(m, field)), isTrue,
        reason: 'the whole decorated field must be masked — prefix, suffix and '
            'label are painted by the decorator, outside the glyph box');
  });

  testWidgets('mask covers the Cupertino field, including its placeholder',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(CupertinoApp(
      home: Center(
        child: CupertinoTextField(
          controller: TextEditingController(text: 'x'),
          placeholder: 'enter card number',
        ),
      ),
    ));

    final field = boxOf(find.byType(CupertinoTextField), tester);
    final wide = masks()
        .any((m) => m.left <= field.left + 0.5 && m.right >= field.right - 0.5);
    expect(wide, isTrue,
        reason:
            'the Cupertino placeholder is a sibling of the editable, so the '
            'mask must span the field, not only the glyph run');
  });

  testWidgets('a field inside a ListTile does not mask the whole row',
      (tester) async {
    // Steady state, deliberately. A freshly discovered adapter has no velocity
    // history, and "unknown velocity" is treated as "could be moving fast" so a
    // presenting modal is not left unmasked — see
    // TextFieldOccludeRenderBox._unknownVelocityWindowMs. That transient inflation
    // is intentional and brief; this test is about the mask's resting geometry, so
    // it lets a first capture discover the field and then advances the clock past
    // the window before asserting.
    var fakeNow = 900000;
    registry
        .debugReplaceTextFieldStore(TextFieldRectStore(clock: () => fakeNow));
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: TextField(
            controller: TextEditingController(text: 'in a tile'),
            decoration: null,
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    ));

    // The first native-screenshot capture discovers the field (and opens the
    // frame pipeline's gate); it is served inflated, which is not what this
    // test is about.
    masks();
    fakeNow += 500; // past the unknown-velocity window
    final tile = boxOf(find.byType(ListTile), tester);
    expect(masks().any((m) => covers(m, tile)), isFalse,
        reason:
            'ListTile is slotted too; resolving to it would mask the leading '
            'and trailing icons and any other row content');
    expect(masks(), isNotEmpty,
        reason: 'the field itself must still be masked');
  });
}
