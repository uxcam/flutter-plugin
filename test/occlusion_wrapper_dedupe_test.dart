import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlude_render_box.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';

/// An app that wraps its fields in `OccludeWrapper` *and* switches the feature
/// on — the migration case — used to send every wrapped field twice: once as
/// the wrapper's rect and once as the field's own. The filled region is the
/// wrapper's rect either way, so the field's rect is dropped when it lies
/// entirely inside an opaque overlay wrapper. A blur wrapper is not opaque, so
/// nothing is dropped for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  Rect rectOf(Map<dynamic, dynamic> r, double dpr) => Rect.fromLTRB(
        (r['left'] as double) / dpr,
        (r['top'] as double) / dpr,
        (r['right'] as double) / dpr,
        (r['bottom'] as double) / dpr,
      );

  bool covers(Rect mask, Rect target) =>
      mask.left <= target.left + 0.5 &&
      mask.top <= target.top + 0.5 &&
      mask.right >= target.right - 0.5 &&
      mask.bottom >= target.bottom - 0.5;

  Rect fieldRect(WidgetTester tester) {
    final box =
        find.byType(TextField).evaluate().single.renderObject as RenderBox;
    return MatrixUtils.transformRect(
        box.getTransformTo(null), Offset.zero & box.size);
  }

  Widget app(Widget body) => MaterialApp(home: Scaffold(body: body));

  testWidgets('a field inside an overlay wrapper is served once',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(app(Center(
      child: OccludeWrapper(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: TextEditingController(text: 'secret'),
            decoration: const InputDecoration(labelText: 'Card'),
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    final dpr = tester.view.devicePixelRatio;
    final served = registry.getOcclusionRects();
    expect(served, hasLength(1),
        reason: 'the wrapper covers the field, so the field must not be sent '
            'a second time');
    expect(covers(rectOf(served.single, dpr), fieldRect(tester)), isTrue,
        reason: 'the one rect served must still cover the field');
  });

  testWidgets('a field outside the wrapper keeps its own rect', (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(app(Column(
      children: [
        const OccludeWrapper(
          child: SizedBox(width: 200, height: 60, child: Text('wrapped')),
        ),
        const SizedBox(height: 40),
        TextField(controller: TextEditingController(text: 'secret')),
      ],
    )));
    await tester.pumpAndSettle();

    final dpr = tester.view.devicePixelRatio;
    final served = registry.getOcclusionRects();
    expect(served, hasLength(2));
    expect(served.any((r) => covers(rectOf(r, dpr), fieldRect(tester))),
        isTrue);
  });

  testWidgets('a blur wrapper never drops the field rect', (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(app(Center(
      child: _BlurWrapper(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: TextEditingController(text: 'secret'),
            decoration: const InputDecoration(labelText: 'Card'),
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(registry.getOcclusionRects(), hasLength(2),
        reason: 'a blur does not fill the region, so the field needs its own '
            'overlay rect');
  });
}

/// `OccludeWrapper` is always an overlay; this is the same render box with the
/// blur type, which the public widget cannot express.
class _BlurWrapper extends SingleChildRenderObjectWidget {
  const _BlurWrapper({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => OccludeRenderBox(
        enabled: true,
        type: OcclusionType.blur,
        registry: OcclusionRegistry.instance,
      )..updateContext(context);
}
