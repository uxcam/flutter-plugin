import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/widgets/occlude2.dart';
import 'package:flutter_uxcam/src/widgets/pixel_grid_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  double? devicePixelRatio;

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
      child: Stack(
        children: [
          widget.child,
          PixelGridOverlay(
            pixelSize: (1 / MediaQuery.of(context).devicePixelRatio) * 50,
          )
        ],
      ),
      key: rootViewkey,
    );
  }

  _captureAppContent() async {
    await WidgetsBinding.instance.endOfFrame;
    if (devicePixelRatio == null) {
      devicePixelRatio = View.of(rootViewkey.currentContext!).devicePixelRatio;
    }
    final boundary = rootViewkey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !boundary.attached) return;

    final image = await boundary.toImage(pixelRatio: devicePixelRatio ?? 1.0);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint paint = Paint();
    canvas.drawImage(image, Offset.zero, paint);

    final Paint rectPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final _occlusionRects = _getOcclusionRects(
        boundary, Size(image.width.toDouble(), image.height.toDouble()));
    for (final rect in _occlusionRects) {
      canvas.drawRect(rect, rectPaint);
    }

    final ui.Image finalImage =
        await recorder.endRecording().toImage(image.width, image.height);

    final byteData = await finalImage.toByteData(format: ImageByteFormat.png);
    final imageBytes = byteData?.buffer.asUint8List();

    if (imageBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final Directory screenshotDir =
          Directory('${directory.path}/screenshots');
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }
      final imagePath =
          await File('${screenshotDir.path}/frame_number_${frameNumber}.png')
              .create();
      await imagePath.writeAsBytes(imageBytes);
      frameNumber += 1;
    }

    image.dispose();
    finalImage.dispose();
  }

  List<Rect> _getOcclusionRects(
      RenderRepaintBoundary boundary, Size imageSize) {
    List<Rect> occlusionBounds = [];
    final boxesToOccclude = BoundsTracker.instance.occludedBoxes;
    for (final box in boxesToOccclude) {
      if (!box.attached || !box.hasSize) continue;
      final Matrix4 m = box.getTransformTo(boundary);
      final Rect rLogical =
          MatrixUtils.transformRect(m, Offset.zero & box.size);
      Rect rPx = Rect.fromLTWH(
        rLogical.left * (devicePixelRatio ?? 1.0),
        rLogical.top * (devicePixelRatio ?? 1.0),
        rLogical.width * (devicePixelRatio ?? 1.0),
        rLogical.height * (devicePixelRatio ?? 1.0),
      );

      occlusionBounds.add(
        Rect.fromLTWH(
          rPx.left.clamp(0.0, imageSize.width),
          rPx.top.clamp(0.0, imageSize.height),
          (rPx.width).clamp(0.0, imageSize.width),
          (rPx.height).clamp(0.0, imageSize.height),
        ),
      );
    }
    return occlusionBounds;
  }

  @override
  void dispose() {
    _screenshotSubscription?.cancel();
    super.dispose();
  }
}
