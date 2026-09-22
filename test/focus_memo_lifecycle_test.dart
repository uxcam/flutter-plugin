import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/focus_tree_detector.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_detector.dart';

/// What the detector remembers between scans must never outlive the tree it
/// describes, and must not outlive the feature.
///
/// A `FocusNode` keeps its `BuildContext` after disposal, so a memo entry keyed
/// on a node the tree has dropped pins the node's element, widget, state and
/// render subtree. A long list recycles hundreds of rows per second; remembering
/// each one until a size cap wiped them all at once grew memory in a sawtooth and
/// paid the wipe as a frame spike. The memo is now bounded by the live focus
/// tree, and switching the feature off releases it entirely.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Live leaf focus nodes — the set the memo is bounded by.
  int liveLeaves() {
    var count = 0;
    void walk(FocusNode node) {
      if (node.children.isEmpty && node is! FocusScopeNode) count++;
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(FocusManager.instance.rootScope);
    return count;
  }

  RenderObject root() => RendererBinding.instance.renderViews.first;

  Widget list({ScrollController? controller}) => MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemExtent: 80,
            itemBuilder: (_, i) => ListTile(
              // An InkWell installs a Focus node per row — the negative-cache
              // case the memo exists for.
              onTap: () {},
              title: TextField(
                controller: TextEditingController(text: 'row $i'),
                decoration: InputDecoration(labelText: 'Field $i'),
              ),
            ),
          ),
        ),
      );

  testWidgets('the memo is bounded by the live focus tree through a long scroll',
      (tester) async {
    final detector = FocusTreeDetector();
    final out = <int, DiscoveredField>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(list(controller: controller));
    await tester.pumpAndSettle();

    detector.collect(root(), out);
    expect(out, isNotEmpty);
    final settledSize = detector.debugMemoSize;
    expect(settledSize, lessThanOrEqualTo(liveLeaves()));

    // Scroll far enough, often enough, to recycle many times the rows on screen.
    // Before the sweep this grew by every row ever seen.
    for (var step = 1; step <= 12; step++) {
      controller.jumpTo(step * 1200.0);
      await tester.pump();
      out.clear();
      detector.collect(root(), out);
      expect(detector.debugMemoSize, lessThanOrEqualTo(liveLeaves()),
          reason: 'after scroll step $step the memo holds more entries than '
              'there are live leaf focus nodes — it is remembering rows the '
              'list has recycled');
    }
    expect(detector.debugMemoSize, lessThanOrEqualTo(settledSize + 8),
        reason: 'the memo should stay the size of one screen, not grow with '
            'the scroll distance');
  });

  testWidgets('a node the tree has dropped is forgotten on the next scan',
      (tester) async {
    final detector = FocusTreeDetector();
    final out = <int, DiscoveredField>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(list(controller: controller));
    await tester.pumpAndSettle();
    detector.collect(root(), out);

    // Hold on to a focus node of a row that is about to be scrolled away.
    final firstField = find.byType(TextField).first;
    final node = tester
        .state<EditableTextState>(find.descendant(
            of: firstField, matching: find.byType(EditableText)))
        .widget
        .focusNode;
    expect(detector.debugRemembers(node), isTrue);

    controller.jumpTo(4000);
    await tester.pump();
    out.clear();
    detector.collect(root(), out);

    expect(detector.debugRemembers(node), isFalse,
        reason: 'the row is gone from the tree; remembering its node would pin '
            'its whole subtree');
  });

  testWidgets('a settled scan sweeps nothing and re-finds every field',
      (tester) async {
    final detector = FocusTreeDetector();
    final first = <int, DiscoveredField>{};
    final second = <int, DiscoveredField>{};

    await tester.pumpWidget(list());
    await tester.pumpAndSettle();

    detector.collect(root(), first);
    final size = detector.debugMemoSize;
    detector.collect(root(), second);

    expect(detector.debugMemoSize, size);
    expect(second.keys.toSet(), first.keys.toSet(),
        reason: 'a second scan of an unchanged tree must find the same fields');
  });

  testWidgets('disabling releases the memo, the store and the buffer',
      (tester) async {
    final registry = OcclusionRegistry.instance;
    registry.resetTextFieldStateForTesting();
    addTearDown(registry.resetTextFieldStateForTesting);

    registry.occludeAllTextFields = true;
    await tester.pumpWidget(list());
    await tester.pumpAndSettle();

    // A capture discovers; the memo and the store now hold the visible rows.
    expect(registry.debugServeRects(coherent: true), isNotEmpty);
    final detector = registry.debugDetector as FocusTreeDetector;
    expect(detector.debugMemoSize, greaterThan(0));
    expect(registry.debugTextFieldStore.adapterCount, greaterThan(0));
    expect(registry.debugDiscoveredBufferLength, 0,
        reason: 'the reused buffer must not pin the last scan between walks');

    registry.occludeAllTextFields = false;

    expect(detector.debugMemoSize, 0,
        reason: 'a feature that is off must not keep focus nodes — and the '
            'subtrees they pin — alive');
    expect(registry.debugTextFieldStore.adapterCount, 0);
    expect(registry.debugDiscoveredBufferLength, 0);

    // Re-enabling rediscovers everything on the first capture.
    registry.occludeAllTextFields = true;
    expect(registry.debugServeRects(coherent: true), isNotEmpty);
  });
}
