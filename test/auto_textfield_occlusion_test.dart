import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_uxcam/src/widgets/textfield_rect_store.dart';

Widget _app(Widget body) => MaterialApp(home: Scaffold(body: body));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = OcclusionRegistry.instance;

  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  /// Delivers a verification statement the way native does, so the registry
  /// recomputes and arms discovery instead of being poked in place.
  Future<void> pushConfiguration(
    WidgetTester tester, {
    required bool flag,
    List<String>? excludeScreens,
  }) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'uxcam_occlusion_request',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('updateOcclusionConfiguration', {
          'occludeAllTextFields': flag,
          if (excludeScreens != null) 'excludeScreens': excludeScreens,
        }),
      ),
      null,
    );
  }

  testWidgets('a TextField produces an occlusion rect in its first frame',
      (tester) async {
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(_app(const TextField()));

    final rects = registry.getOcclusionRects();
    expect(rects, hasLength(1));
    final rect = rects.single;
    expect(
        (rect['right'] as double) - (rect['left'] as double), greaterThan(0));
    expect(
        (rect['bottom'] as double) - (rect['top'] as double), greaterThan(0));
  });

  testWidgets('multiple fields each get a rect', (tester) async {
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(_app(const Column(
      children: [TextField(), TextField(), TextField()],
    )));

    expect(registry.getOcclusionRects(), hasLength(3));
  });

  testWidgets(
      'removed field is served for the grace window, then expires — never a stale position after that',
      (tester) async {
    var fakeNow = 1000;
    registry
        .debugReplaceTextFieldStore(TextFieldRectStore(clock: () => fakeNow));
    registry.occludeAllTextFields = true;

    await tester.pumpWidget(_app(const TextField()));
    expect(registry.getOcclusionRects(), hasLength(1));

    // Replace the tree without the field; tier-1 prunes the detached adapter
    // into a grace rect on the same pump.
    await tester.pumpWidget(_app(const SizedBox()));
    expect(registry.getOcclusionRects(), hasLength(1),
        reason: 'grace rect must cover a capture racing the detach');

    // Past the grace TTL nothing may be served.
    fakeNow += TextFieldRectStore.graceTtlMs + 1;
    expect(registry.getOcclusionRects(), isEmpty);
  });

  testWidgets('disabling clears held rects immediately', (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(_app(const TextField()));
    expect(registry.getOcclusionRects(), isNotEmpty);

    registry.occludeAllTextFields = false;
    expect(registry.getOcclusionRects(), isEmpty);
  });

  testWidgets('excludeScreens rule follows the Flutter-supplied screen name',
      (tester) async {
    // The screen scope belongs to the configuration rule, so the rule has to be
    // delivered as a configuration statement — not paired with an API call.
    await pushConfiguration(tester, flag: true, excludeScreens: ['Search']);

    // On the excluded screen: no text-field occlusion.
    registry.currentScreenName = 'Search';
    await tester.pumpWidget(_app(const TextField()));
    expect(registry.getOcclusionRects(), isEmpty);

    // Navigating to a non-excluded screen re-enables it.
    registry.currentScreenName = 'Login';
    await tester.pump();
    expect(registry.getOcclusionRects(), isNotEmpty);
  });

  testWidgets("a config exclusion does not narrow the API's blanket request",
      (tester) async {
    await pushConfiguration(tester, flag: true, excludeScreens: ['Search']);
    registry.occludeAllTextFields = true;

    registry.currentScreenName = 'Search';
    await tester.pumpWidget(_app(const TextField()));

    expect(registry.getOcclusionRects(), isNotEmpty,
        reason:
            'the API takes no screen argument, so it asks for every screen; '
            'honouring the server exclusion here would let the server remove '
            'occlusion the developer asked for');
  });

  testWidgets('a stale config statement does not outlive its session',
      (tester) async {
    await tester.pumpWidget(_app(const TextField()));
    await pushConfiguration(tester, flag: true);
    expect(registry.getOcclusionRects(), isNotEmpty);

    registry.resetConfigurationLayer();

    expect(registry.getOcclusionRects(), isEmpty,
        reason: 'startWithConfiguration drops the previous session config, and '
            'held rects must go with it');
  });
}
