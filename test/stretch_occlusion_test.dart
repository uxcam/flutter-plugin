import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlude_render_box.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';
import 'package:flutter_uxcam/src/widgets/stretch_detector.dart';
import 'package:flutter_uxcam/src/widgets/stretch_map.dart';

/// StretchEffect's shader-path shape. The test engine has no Impeller, so the
/// real one always falls back to a Transform here.
class FakeStretchEffect extends StatelessWidget {
  const FakeStretchEffect({
    super.key,
    required this.stretchStrength,
    required this.axis,
    this.enabled = true,
    required this.child,
  });

  final double stretchStrength;
  final Axis axis;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _FakeOverscrollEffect(enabled: enabled, child: child);
}

class _FakeOverscrollEffect extends StatefulWidget {
  const _FakeOverscrollEffect({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_FakeOverscrollEffect> createState() => _FakeOverscrollEffectState();
}

class _FakeOverscrollEffectState extends State<_FakeOverscrollEffect> {
  @override
  Widget build(BuildContext context) => ImageFiltered(
        imageFilter: ui.ImageFilter.matrix(Matrix4.identity().storage),
        enabled: widget.enabled,
        child: widget.child,
      );
}

const _area = Size(400, 600);
const _box = Rect.fromLTWH(50, 300, 100, 60);

Widget _frame(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: _area, child: child),
      ),
    );

Widget _boxAt(Rect r) => Stack(children: [
      Positioned.fromRect(
        rect: r,
        child: const OccludeWrapper(child: SizedBox.expand()),
      ),
    ]);

Rect _bounds(WidgetTester tester) {
  final box =
      tester.renderObject<OccludeRenderBox>(find.byType(OccludeWrapper));
  box.updateBoundsFromTransform();
  return box.currentBounds!;
}

Rect _snap(Rect r, double dpr) => Rect.fromLTRB(
      (r.left * dpr).roundToDouble() / dpr,
      (r.top * dpr).roundToDouble() / dpr,
      (r.right * dpr).roundToDouble() / dpr,
      (r.bottom * dpr).roundToDouble() / dpr,
    );

Rect _cover(Rect r, Rect container, Axis axis, double s) =>
    r.expandToInclude(StretchMap.remapRect(r, container, axis, s));

void main() {
  testWidgets('a box under a shader stretch also covers where it is drawn',
      (tester) async {
    await tester.pumpWidget(_frame(FakeStretchEffect(
      stretchStrength: 0.03,
      axis: Axis.vertical,
      child: _boxAt(_box),
    )));
    final dpr = tester.view.devicePixelRatio;
    final expected =
        _snap(_cover(_box, Offset.zero & _area, Axis.vertical, 0.03), dpr);
    expect(_bounds(tester), expected);
    expect(expected.top, _box.top);
    expect(expected.bottom, greaterThan(_box.bottom));
  });

  testWidgets('a disabled filter (stretch 0) leaves the box alone',
      (tester) async {
    await tester.pumpWidget(_frame(FakeStretchEffect(
      stretchStrength: 0.03,
      axis: Axis.vertical,
      enabled: false,
      child: _boxAt(_box),
    )));
    expect(_bounds(tester), _box);
  });

  testWidgets('an ImageFiltered that is not a stretch is ignored',
      (tester) async {
    await tester.pumpWidget(_frame(ImageFiltered(
      imageFilter: ui.ImageFilter.matrix(Matrix4.identity().storage),
      child: _boxAt(_box),
    )));
    expect(_bounds(tester), _box);
  });

  testWidgets('nested stretches apply innermost first', (tester) async {
    const row = Rect.fromLTWH(0, 200, 400, 200);
    await tester.pumpWidget(_frame(FakeStretchEffect(
      stretchStrength: 0.03,
      axis: Axis.vertical,
      child: Stack(children: [
        Positioned.fromRect(
          rect: row,
          child: FakeStretchEffect(
            stretchStrength: -0.05,
            axis: Axis.horizontal,
            child: _boxAt(const Rect.fromLTWH(250, 50, 100, 60)),
          ),
        ),
      ]),
    )));
    final box = const Rect.fromLTWH(250, 50, 100, 60).shift(row.topLeft);
    final inner = _cover(box, row, Axis.horizontal, -0.05);
    final both = _cover(inner, Offset.zero & _area, Axis.vertical, 0.03);
    expect(_bounds(tester), _snap(both, tester.view.devicePixelRatio));
    expect(both.left, lessThan(box.left));
    expect(both.bottom, greaterThan(box.bottom));
  });

  testWidgets('a clip below the filter is stretched, a clip above is not',
      (tester) async {
    const clip = Rect.fromLTWH(0, 0, 400, 320);
    final dpr = tester.view.devicePixelRatio;
    final clipped = _box.intersect(clip);

    await tester.pumpWidget(_frame(FakeStretchEffect(
      stretchStrength: 0.03,
      axis: Axis.vertical,
      child: ClipRect(
        clipper: const _Fixed(clip),
        child: _boxAt(_box),
      ),
    )));
    final below = _bounds(tester);
    expect(below,
        _snap(_cover(clipped, Offset.zero & _area, Axis.vertical, 0.03), dpr));
    expect(below.bottom, greaterThan(clip.bottom));

    await tester.pumpWidget(_frame(ClipRect(
      clipper: const _Fixed(clip),
      child: FakeStretchEffect(
        stretchStrength: 0.03,
        axis: Axis.vertical,
        child: _boxAt(_box),
      ),
    )));
    expect(_bounds(tester), _snap(clipped, dpr));
  });

  testWidgets('the real indicator: no remap when the stretch is a Transform',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: ListView.builder(
        itemCount: 30,
        itemExtent: 50,
        itemBuilder: (context, i) => i == 8
            ? const OccludeWrapper(child: SizedBox.expand())
            : const SizedBox.expand(),
      ),
    ));
    final atRest = _bounds(tester);
    final gesture = await tester.startGesture(const Offset(200, 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final filters = tester
        .widgetList<ImageFiltered>(find.byType(ImageFiltered))
        .where((f) => f.enabled);
    final element = tester.element(find.byType(OccludeWrapper));
    final stretches = findShaderStretches(element);
    final stretched = _bounds(tester);
    final box = tester.renderObject<RenderBox>(find.byType(OccludeWrapper));
    final viaTransform = MatrixUtils.transformRect(
        box.getTransformTo(null), Offset.zero & box.size);

    if (filters.isEmpty) {
      expect(stretches, isEmpty);
      expect(stretched, _snap(viaTransform, tester.view.devicePixelRatio));
      expect(stretched.bottom, greaterThan(atRest.bottom));
    } else {
      expect(stretches, hasLength(1));
      expect(stretches.single.axis, Axis.vertical);
      expect(stretches.single.strength, greaterThan(0));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  });
}

class _Fixed extends CustomClipper<Rect> {
  const _Fixed(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  Rect getApproximateClipRect(Size size) => rect;

  @override
  bool shouldReclip(_Fixed oldClipper) => oldClipper.rect != rect;
}
