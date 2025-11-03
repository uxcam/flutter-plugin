import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:path_provider/path_provider.dart';

class UxcamOverlay extends StatefulWidget {
  final Widget child;
  UxcamOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<UxcamOverlay> createState() => _UxcamOverlayState();
}

class _UxcamOverlayState extends State<UxcamOverlay> {
  GlobalKey rootViewkey = GlobalKey();
  final eventChannel = EventChannel('screenshot_event');
  StreamSubscription? _screenshotSubscription;
  int frameNumber = 0;

  @override
  void initState() {
    super.initState();
    _screenshotSubscription =
        eventChannel.receiveBroadcastStream().listen((event) {
      _captureAppContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: widget.child,
      key: rootViewkey,
    );
  }

  _captureAppContent() async {
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;

    final context = rootViewkey.currentContext;
    if (context == null) return;
    final entries = RouteOverlay.maybeOf(context)?.entries ?? [];
    // print(entries);

    // final navigator = Navigator.of(context!, rootNavigator: true);
    // final overlayState = navigator.overlay;
    // if (overlayState == null) return null;

    // // Get the last (topmost) OverlayEntry
    // final entries = overlayState.widget.initialEntries ?? [];
    // if (entries.isEmpty) return null;

    // OverlayEntry.child is usually a Page or route content
    //final topEntry = entries.last;

    // double devicePixelRatio = View.of(context!).devicePixelRatio;

    // final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    // if (boundary == null || !boundary.attached) return;

    // final _occlusionRects = _getOcclusionRects(boundary, devicePixelRatio);
    // final image = await boundary.toImage(pixelRatio: devicePixelRatio);
    // final ui.PictureRecorder recorder = ui.PictureRecorder();
    // final Canvas canvas = Canvas(recorder);
    // canvas.drawImage(image, Offset.zero, Paint());

    // final Paint rectPaint = Paint()
    //   ..color = Colors.red
    //   ..style = PaintingStyle.fill;
    // for (final rect in _occlusionRects) {
    //   canvas.drawRect(rect, rectPaint);
    // }

    // final ui.Image finalImage =
    //     await recorder.endRecording().toImage(image.width, image.height);

    // final byteData = await finalImage.toByteData(format: ImageByteFormat.png);
    // final imageBytes = byteData?.buffer.asUint8List();

    // if (imageBytes != null) {
    //   _persistScreenshotsForDebugging(imageBytes);
    //   FlutterUxcam.sendFrameScreenshot(imageBytes);
    //   frameNumber += 1;
    // }

    // image.dispose();
    // finalImage.dispose();
  }

  bool _isBoxVisibleOnScreen(RenderBox box, RenderRepaintBoundary root) {
    if (!box.attached || !box.hasSize) return false;

    RenderObject? current = box;
    while (current != null) {
      if (current is RenderOffstage && current.offstage) return false;
      if (current is RenderOpacity && current.opacity == 0.0) return false;
      current = current.parent;
    }

    final Matrix4 m = box.getTransformTo(root);
    final Rect rectLogical =
        MatrixUtils.transformRect(m, Offset.zero & box.size);
    final Rect viewportLogical = Offset.zero & root.size;
    final Rect visible = rectLogical.intersect(viewportLogical);
    return !visible.isEmpty && visible.width > 0 && visible.height > 0;
  }

  List<Rect> _getOcclusionRects(
      RenderRepaintBoundary boundary, double devicePixelRatio) {
    List<Rect> occlusionBounds = [];
    final boxesToOccclude = BoundsTracker.instance.occludedBoxes();
    for (final box in boxesToOccclude) {
      if (!box.attached || !box.hasSize) continue;
      final Matrix4 m = box.getTransformTo(boundary);
      final Rect rLogical =
          MatrixUtils.transformRect(m, Offset.zero & box.size);
      Rect rPx = Rect.fromLTWH(
        rLogical.left * devicePixelRatio,
        rLogical.top * devicePixelRatio,
        rLogical.width * devicePixelRatio,
        rLogical.height * devicePixelRatio,
      );

      occlusionBounds.add(rPx);
    }
    return occlusionBounds;
  }

  _persistScreenshotsForDebugging(Uint8List imageBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final Directory screenshotDir = Directory('${directory.path}/screenshots');
    if (!await screenshotDir.exists()) {
      await screenshotDir.create(recursive: true);
    }
    final imagePath =
        await File('${screenshotDir.path}/frame_number_${frameNumber}.png')
            .create();
    await imagePath.writeAsBytes(imageBytes);
  }

  @override
  void dispose() {
    _screenshotSubscription?.cancel();
    super.dispose();
  }
}
