import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

/// Every field the user can see stays masked for the whole of a route push.
///
/// A route slide moves a field several hundred pixels in under 400 ms, which is
/// the hardest case for two mechanisms: the sliding-window union, which only
/// covers where a field has *been*, and forced discovery, which has to find the
/// incoming route's field before it is painted rather than several frames later.
///
/// Both halves of the harness matter, and getting either wrong silently changes
/// the verdict rather than failing:
///
///  * The adapter's window must age on the same injected clock as the registry's
///    cadence. Left on the wall clock it never expires during a fast test, and
///    the union grows to cover everything.
///  * The oracle must ignore fields hidden by a zero opacity. A transition fades
///    the outgoing page out while its subtree stays mounted and laid out, so
///    "attached and sized" demands a mask over a field that is not on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  List<Rect> masks() => registry
      .getOcclusionRects()
      .map((r) => Rect.fromLTRB(
          (r['left'] as double) / 3,
          (r['top'] as double) / 3,
          (r['right'] as double) / 3,
          (r['bottom'] as double) / 3))
      .toList();

  /// True when every opacity ancestor is at least partly opaque, i.e. the user
  /// can actually see this field.
  ///
  /// Deliberately independent of `resolveOcclusionGeometry`: the oracle must not
  /// be the production rule it is checking. A route transition fades the outgoing
  /// page to `opacity == 0` while its subtree is still mounted and laid out, so a
  /// naive "attached and sized" check demands a mask over a field that is not on
  /// screen.
  bool onScreen(RenderObject node) {
    RenderObject? current = node;
    while (current != null) {
      if (current is RenderAnimatedOpacity && current.opacity.value <= 0) {
        return false;
      }
      if (current is RenderOpacity && current.opacity <= 0) return false;
      current = current.parent;
    }
    return true;
  }

  // Every RenderEditable the user can actually see, with its global rect.
  List<Rect> visibleFields() {
    final out = <Rect>[];
    void walk(RenderObject r) {
      if (r is RenderEditable && r.attached && r.hasSize && onScreen(r)) {
        out.add(r.localToGlobal(Offset.zero) & r.size);
      }
      r.visitChildren(walk);
    }

    walk(RendererBinding.instance.renderViews.first);
    return out;
  }

  bool covered(Rect field, List<Rect> ms) => ms.any((m) =>
      m.left <= field.left + 1 &&
      m.top <= field.top + 1 &&
      m.right >= field.right - 1 &&
      m.bottom >= field.bottom - 1);

  testWidgets('TRANSITION: fields stay masked through a route push', (t) async {
    // Drive the algorithm's real cadence rather than the test's execution speed.
    var fakeNow = 500000;
    registry.debugSetClock(() => fakeNow);
    // The adapter's sliding window must age on the same clock as the registry's
    // cadence, or the window never expires and the union flatters the result.
    registry
        .debugReplaceTextFieldStore(TextFieldRectStore(clock: () => fakeNow));
    registry.occludeAllTextFields = true;
    final nav = GlobalKey<NavigatorState>();

    Widget page(String label) => Scaffold(
        body: Center(
            child: TextField(
                controller: TextEditingController(text: 'secret-$label'),
                decoration: InputDecoration(
                    labelText: label, border: const OutlineInputBorder()))));

    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: page('first')));
    await t.pumpAndSettle();
    expect(masks(), hasLength(1));

    nav.currentState!.push(MaterialPageRoute(builder: (_) => page('second')));

    // Step through the transition frame by frame.
    var exposedFrames = 0;
    var worstGap = 0.0;
    final failures = <String>[];
    for (var i = 0; i < 22; i++) {
      fakeNow += 16;
      await t.pump(const Duration(milliseconds: 16));
      final ms = masks();
      final fields = visibleFields();
      final uncovered = fields.where((f) => !covered(f, ms)).toList();
      if (uncovered.isEmpty) continue;

      exposedFrames++;
      for (final u in uncovered) {
        for (final m in ms) {
          if ((m.center - u.center).distance < u.width) {
            final gap = [
              m.left - u.left,
              m.top - u.top,
              u.right - m.right,
              u.bottom - m.bottom,
            ].reduce((a, b) => a > b ? a : b);
            if (gap > worstGap) worstGap = gap;
          }
        }
      }
      if (failures.length < 4) {
        failures.add('frame $i: ${uncovered.length}/${fields.length} '
            'uncovered, fields=$fields masks=$ms');
      }
    }

    expect(exposedFrames, 0,
        reason: 'exposed on $exposedFrames of 22 transition frames, worst gap '
            '${worstGap.toStringAsFixed(1)}px\n${failures.join('\n')}');
  });
}
