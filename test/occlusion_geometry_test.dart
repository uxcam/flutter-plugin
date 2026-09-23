import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_geometry.dart';

import 'occlusion_geometry_reference.dart';

/// Equivalence guard for the single-pass [resolveOcclusionGeometry].
///
/// It replaced three separate ancestor traversals with one, rewriting how the
/// paint transform is accumulated and how ancestor clips are globalised. The
/// The three original helpers live in `occlusion_geometry_reference.dart` purely
/// so the fast path can be checked against them: same tree, same answers.
///
/// The trees below are chosen to exercise what the composition can get wrong —
/// nested transforms (order of matrix multiplication), several stacked clips
/// (intersection in global space), and a scroll viewport (a clip whose own
/// ancestor transform is non-identity).
void main() {
  RenderBox boxOfKey(GlobalKey key) =>
      key.currentContext!.findRenderObject()! as RenderBox;

  void expectEquivalent(RenderBox box, {required String forTree}) {
    final resolved = resolveOcclusionGeometry(box);

    // Transform must match `getTransformTo(null)` exactly — it is the same
    // composition, just accumulated in one pass instead of two.
    expect(resolved.transform.storage, box.getTransformTo(null).storage,
        reason: 'transform diverged for $forTree');

    final expectedClip = calculateEffectiveClip(box);
    if (expectedClip == null) {
      expect(resolved.clip, isNull, reason: 'spurious clip for $forTree');
    } else {
      expect(resolved.clip, isNotNull, reason: 'missing clip for $forTree');
      // Float composition order differs, so compare within a sub-pixel epsilon
      // rather than demanding bit equality.
      expect(resolved.clip!.left, closeTo(expectedClip.left, 0.01),
          reason: 'clip.left diverged for $forTree');
      expect(resolved.clip!.top, closeTo(expectedClip.top, 0.01),
          reason: 'clip.top diverged for $forTree');
      expect(resolved.clip!.right, closeTo(expectedClip.right, 0.01),
          reason: 'clip.right diverged for $forTree');
      expect(resolved.clip!.bottom, closeTo(expectedClip.bottom, 0.01),
          reason: 'clip.bottom diverged for $forTree');
    }

    expect(resolved.isVisible, !isRenderObjectEffectivelyInvisible(box),
        reason: 'visibility diverged for $forTree');
  }

  testWidgets('matches the three-walk helpers: plain, unclipped', (t) async {
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Center(child: SizedBox(key: key, width: 80, height: 20))),
    ));
    expectEquivalent(boxOfKey(key), forTree: 'plain');
  });

  testWidgets('matches under nested transforms', (t) async {
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Transform.translate(
          offset: const Offset(13, 27),
          child: Transform.scale(
            scale: 1.5,
            child: Transform.rotate(
              angle: 0.3,
              child: SizedBox(key: key, width: 80, height: 20),
            ),
          ),
        ),
      ),
    ));
    expectEquivalent(boxOfKey(key), forTree: 'nested transforms');
  });

  testWidgets('matches under stacked clips', (t) async {
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ClipRect(
            child: SizedBox(
              width: 200,
              height: 100,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 150,
                    height: 60,
                    child: Center(
                      child: SizedBox(key: key, width: 300, height: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    expectEquivalent(boxOfKey(key), forTree: 'stacked clips');
  });

  testWidgets('matches inside a scrolled viewport', (t) async {
    final key = GlobalKey();
    final controller = ScrollController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            for (int i = 0; i < 20; i++)
              SizedBox(
                height: 60,
                child: i == 10
                    ? SizedBox(key: key, width: 120, height: 20)
                    : const Text('row'),
              ),
          ],
        ),
      ),
    ));
    // Scroll so the target sits partly clipped by the viewport edge — the case
    // where a clip's own ancestor transform is non-identity.
    controller.jumpTo(590);
    await t.pump();

    expectEquivalent(boxOfKey(key), forTree: 'scrolled viewport');
    controller.dispose();
  });

  testWidgets('matches a real TextField inside a scrolled form', (t) async {
    final key = GlobalKey();
    final controller = ScrollController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            for (int i = 0; i < 15; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  key: i == 7 ? key : null,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
          ],
        ),
      ),
    ));
    controller.jumpTo(120);
    await t.pump();

    expectEquivalent(boxOfKey(key), forTree: 'TextField in scrolled form');
    controller.dispose();
  });

  testWidgets('reports invisible for a hidden IndexedStack branch', (t) async {
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IndexedStack(
          index: 0,
          children: [
            const Text('shown'),
            SizedBox(key: key, width: 80, height: 20),
          ],
        ),
      ),
    ));

    final box = boxOfKey(key);
    expect(resolveOcclusionGeometry(box).isVisible, isFalse);
    // The chain must still be resolved when hidden — callers that already know a
    // node may be hidden still need its transform.
    expect(resolveOcclusionGeometry(box).transform.storage,
        box.getTransformTo(null).storage);
    expectEquivalent(box, forTree: 'hidden IndexedStack branch');
  });

  testWidgets(
      'reports invisible for a route beneath an opaque one, and visible again '
      'once it is popped', (t) async {
    final key = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: Scaffold(
          body: Center(child: SizedBox(key: key, width: 80, height: 20))),
    ));
    final box = boxOfKey(key);
    expect(resolveOcclusionGeometry(box).isVisible, isTrue);

    // A Cupertino slide neither fades nor offstages the outgoing page, so once
    // the push has settled only the overlay's skip says it is off screen.
    nav.currentState!.push(CupertinoPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('over'))));
    await t.pumpAndSettle();
    expect(box.attached, isTrue, reason: 'the route beneath stays mounted');
    expect(resolveOcclusionGeometry(box).isVisible, isFalse);
    expectEquivalent(box, forTree: 'route beneath an opaque route');

    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(resolveOcclusionGeometry(box).isVisible, isTrue);
    expectEquivalent(box, forTree: 'route popped back on stage');
  });

  testWidgets('buffer reuse does not leak state between calls', (t) async {
    final a = GlobalKey();
    final b = GlobalKey();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Transform.translate(
            offset: const Offset(40, 0),
            child: SizedBox(key: a, width: 50, height: 20),
          ),
          SizedBox(key: b, width: 50, height: 20),
        ]),
      ),
    ));

    // The scratch chain buffer is shared across calls; interleaving two different
    // nodes would surface any failure to clear it.
    final firstA = resolveOcclusionGeometry(boxOfKey(a)).transform.clone();
    resolveOcclusionGeometry(boxOfKey(b));
    final secondA = resolveOcclusionGeometry(boxOfKey(a)).transform;

    expect(secondA.storage, firstA.storage);
  });
}
