import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/focus_tree_detector.dart';
import 'package:flutter_uxcam/src/widgets/textfield_detector.dart';

/// Coverage guard for lever 4.
///
/// [FocusTreeDetector] is a performance change with a privacy failure mode: a
/// field the focus tree does not contain silently stops being masked, and nothing
/// looks wrong on screen. So it cannot be adopted on a speed number — it has to
/// be shown to find *everything* the render-tree walk finds.
///
/// The tree below mirrors the demo app's `OcclusionFieldFixture`, field type for
/// field type, including the two traps: `ExcludeFocus` and `ExcludeSemantics`.
/// Both render normally and hold real data; both are the kind of widget that
/// could plausibly hide a field from an alternative detector.
///
/// The render-tree walk is the reference. It finds every `RenderEditable` by
/// construction, so parity with it is the definition of correct here.
void main() {
  /// Every RenderEditable actually in the tree — the ground truth.
  List<RenderEditable> groundTruth() {
    final found = <RenderEditable>[];
    void walk(RenderObject r) {
      if (r is RenderEditable) found.add(r);
      r.visitChildren(walk);
    }

    walk(RendererBinding.instance.renderViews.first);
    return found;
  }

  /// Resolves a detector's output back to the underlying editables, so the two
  /// detectors can be compared even though they may target the decorator box.
  Set<RenderEditable> editablesFrom(TextFieldDetector detector) {
    final out = <int, DiscoveredField>{};
    detector.collect(RendererBinding.instance.renderViews.first, out);

    final editables = <RenderEditable>{};
    for (final field in out.values) {
      RenderEditable? found;
      void descend(RenderObject r) {
        if (found != null) return;
        if (r is RenderEditable) {
          found = r;
          return;
        }
        r.visitChildren(descend);
      }

      descend(field.box);
      if (found != null) editables.add(found!);
    }
    return editables;
  }

  Widget fixture() {
    Widget material(String label, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(
            controller: TextEditingController(text: text),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Prefilled and empty Material fields.
              material('Full name', 'Alexandra Whitfield'),
              material('Card number', '4111 1111 1111 1111'),
              material('Middle name', ''),

              // No InputDecorator ancestor at all.
              SizedBox(
                height: 40,
                child: EditableText(
                  controller: TextEditingController(text: 'bare editable'),
                  focusNode: FocusNode(),
                  style: const TextStyle(),
                  cursorColor: CupertinoColors.activeBlue,
                  backgroundCursorColor: CupertinoColors.inactiveGray,
                ),
              ),

              // Field box is a plain RenderDecoratedBox, not a slotted decorator.
              CupertinoTextField(
                controller: TextEditingController(text: 'cupertino'),
              ),

              // ListTile is also a slotted render object.
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: TextField(
                  controller: TextEditingController(text: 'in a tile'),
                  decoration: null,
                ),
              ),

              // States that are still sensitive.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: TextEditingController(text: 'sup3r-s3cret'),
                  obscureText: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: TextEditingController(text: 'read only'),
                  readOnly: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: TextEditingController(text: 'disabled'),
                  enabled: false,
                ),
              ),

              // The two traps.
              ExcludeFocus(
                  child: material('No focus', 'hidden from focus tree')),
              ExcludeSemantics(
                child: material('No semantics', 'hidden from semantics tree'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('focus tree finds every field the render tree finds',
      (tester) async {
    // Tall enough that nothing is scrolled out of the tree, so the two detectors
    // are compared against the same field population.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(fixture());
    await tester.pumpAndSettle();

    final truth = groundTruth().toSet();
    expect(truth.length, greaterThanOrEqualTo(10),
        reason: 'fixture should present at least ten editables');

    final viaFocus = editablesFrom(FocusTreeDetector());
    final viaRender = editablesFrom(const RenderEditableDetector());

    expect(viaRender, truth,
        reason:
            'the render-tree detector is the reference and must be complete');

    final missed = truth.difference(viaFocus);
    expect(
      missed,
      isEmpty,
      reason: 'focus-tree detection MISSED ${missed.length} field(s): '
          '${missed.map((e) => '"${e.text?.toPlainText()}"').join(', ')}. '
          'Each one would render normally and silently go unmasked. Lever 4 '
          'cannot ship while this fails.',
    );
  });

  testWidgets('ExcludeFocus does not hide a field from the focus tree',
      (tester) async {
    // Called out separately because it is the single assumption lever 4 rests on,
    // and it is behaviour of the Flutter version in use rather than a documented
    // guarantee. If an upgrade changes it, this fails loudly here instead of
    // quietly in a customer session.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExcludeFocus(
          child: TextField(
            controller: TextEditingController(text: 'excluded but visible'),
          ),
        ),
      ),
    ));

    expect(editablesFrom(FocusTreeDetector()), hasLength(1),
        reason: 'ExcludeFocus must not remove the node from the focus tree');
  });
}
