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
    final boundary = rootViewkey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    final image =
        await boundary?.toImage(pixelRatio: ui.window.devicePixelRatio);
    if (image != null) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      final Paint paint = Paint();
      canvas.drawImage(image, Offset.zero, paint);

      final Paint rectPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      final _occlusionRects = _getOcclusionRects();
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
    }
  }

  List<Rect> _getOcclusionRects() {
    final rects = BoundsTracker.instance.rects.values.toList();
    return rects;
  }

  @override
  void dispose() {
    _screenshotSubscription?.cancel();
    super.dispose();
  }
}
