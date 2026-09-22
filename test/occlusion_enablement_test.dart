import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/internal/motion_reporter.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';

/// Enablement must not depend on a frame being produced.
///
/// Discovery runs from a persistent frame callback, and a settled screen produces
/// no frames — so without these paths, the feature turns on and then nothing ever
/// discovers the fields on the screen already being displayed.
///
/// Enablement has exactly two sources: the Dart API, and a verification
/// `updateOcclusionConfiguration` statement. The per-capture `occludeAllTextFields`
/// flag is deliberately not one of them (see `TextFieldOcclusionPolicy`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = OcclusionRegistry.instance;
  setUp(registry.resetTextFieldStateForTesting);
  tearDown(registry.resetTextFieldStateForTesting);

  Widget app() => MaterialApp(
        home: Scaffold(
          body: TextField(controller: TextEditingController(text: 'secret')),
        ),
      );

  Future<dynamic> send(WidgetTester tester, MethodCall call,
      {String channel = 'uxcam_occlusion_request'}) async {
    final data =
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeMethodCall(call),
      null,
    );
    // A capture request marks the native side as recording, which arms the
    // motion reporter's 5 s idle timer. The binding fails a test that ends with
    // a timer outstanding, and the reporter is not what these tests are about.
    MotionReporter.instance.debugReset();
    return const StandardMethodCodec().decodeEnvelope(data!);
  }

  Future<List<dynamic>> capture(WidgetTester tester, {bool flag = true}) async {
    final call =
        MethodCall('requestOcclusionRects', {'occludeAllTextFields': flag});
    return await send(tester, call) as List<dynamic>;
  }

  Future<void> pushConfiguration(WidgetTester tester, {bool flag = true}) =>
      send(
          tester,
          MethodCall('updateOcclusionConfiguration', {
            'occludeAllTextFields': flag,
            'screens': <String>[],
            'excludeMentionedScreens': false,
          }));

  testWidgets('the first capture after a config statement masks its own frame',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await pushConfiguration(tester);

    expect(await capture(tester), hasLength(1),
        reason:
            'the statement lands between frames on a settled screen, so the '
            'very next capture must already be masked — not merely the one '
            'after it');
  });

  testWidgets('the capture that carries the flag masks its own frame',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // On iOS this is the only channel a verification response has: the SDK sends
    // no `updateOcclusionConfiguration`, so a dashboard-enabled app is masked in
    // Flutter solely because the flag rides along with the capture request.
    expect(await capture(tester), hasLength(1),
        reason: 'the flag arrives with this capture, so this capture must be '
            'masked — not merely the next one');
  });

  testWidgets('a capture flag of false leaves nothing masked', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(await capture(tester, flag: false), isEmpty);
  });

  testWidgets(
      'the iOS verification sequence masks without any app code: '
      'requestSceneFrame(true) then requestAllOcclusionRects', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Exactly what the iOS SDK does. There is no `updateOcclusionConfiguration`
    // sender on iOS and the app never calls the Dart API, so if this sequence
    // does not mask, a dashboard-enabled app records its text fields in clear.
    // `includePixels: false` isolates the settings-application behavior this
    // test targets from the (unrelated) scene-pixel-capture path, which needs
    // a real attached rendering pipeline that the widget-test harness doesn't
    // drive to completion.
    await send(
        tester,
        const MethodCall('requestSceneFrame',
            {'occludeAllTextFields': true, 'includePixels': false}),
        channel: 'flutter_uxcam');

    final rects = await send(tester,
        const MethodCall('requestAllOcclusionRects', <String, dynamic>{}),
        channel: 'flutter_uxcam') as List<dynamic>;

    expect(rects, hasLength(1),
        reason: 'verification enabled it natively; Flutter must honour that '
            'without the app calling occludeAllTextFields');
  });

  testWidgets('enabling on a settled screen discovers without a new frame',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    registry.occludeAllTextFields = true;

    expect(registry.getOcclusionRects(), hasLength(1),
        reason:
            'a settled screen produces no frames, so enablement cannot wait '
            'for a frame callback to run discovery');
  });

  testWidgets(
      'enabling does not wake a settled screen while every capture is coherent',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    registry.occludeAllTextFields = true;

    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'the capture path discovers on its own, so a frame here would '
            'only cost a frame; the previous test shows the next capture is '
            'masked regardless');
  });

  testWidgets(
      'enabling wakes a frame once a native-screenshot capture has been seen',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // A rects-only capture is served to a native screenshot, so the frame
    // pipeline has to run from here on — and arming a forced discovery is
    // pointless if no frame is coming.
    await capture(tester);

    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'the pipeline is active after a native-screenshot capture, so '
            'arming discovery must request the frame it runs on');
  });

  testWidgets('a screen change on a settled screen still discovers',
      (tester) async {
    registry.occludeAllTextFields = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    registry.currentScreenName = 'Checkout';

    expect(registry.getOcclusionRects(), hasLength(1));
  });
}
