import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlude2.dart';
import 'package:flutter_uxcam/src/helpers/channel_callback.dart';
import 'package:path_provider/path_provider.dart';
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
  
  /// Static method to capture app content from channel callback
  static Future<Uint8List?> captureAppContent() async {
    return await _UxcamOverlayState.captureAppContent();
  }
}

class _UxcamOverlayState extends State<UxcamOverlay> {
  GlobalKey rootViewkey = GlobalKey();
  final eventChannel = EventChannel('screenshot_event');
  StreamSubscription? _screenshotSubscription;
  int frameNumber = 0;
  
  // Static reference to access instance from channel callback
  static _UxcamOverlayState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
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

  Future<Uint8List?> _captureAppContent() async {
    if (!mounted) return null;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    final context = rootViewkey.currentContext;
    if (context == null) return null;

    // final navigator = Navigator.of(context!, rootNavigator: true);
    // final overlayState = navigator.overlay;
    // if (overlayState == null) return null;

    // // Get the last (topmost) OverlayEntry
    // final entries = overlayState.widget.initialEntries ?? [];
    // if (entries.isEmpty) return null;

    // OverlayEntry.child is usually a Page or route content
    //final topEntry = entries.last;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    double devicePixelRatio = View.of(context).devicePixelRatio;

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.attached) return null;

    final _occlusionRects = _getOcclusionRects(boundary, devicePixelRatio);
    final image = await boundary.toImage(pixelRatio: devicePixelRatio);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    final Paint rectPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    for (final rect in _occlusionRects) {
      canvas.drawRect(rect, rectPaint);
    }

    final ui.Image finalImage =
        await recorder.endRecording().toImage(image.width, image.height);

    ChannelCallback.cachedImage = finalImage;

    final byteData = await finalImage.toByteData(format: ImageByteFormat.png);
    final imageBytes = byteData?.buffer.asUint8List();

    if (Platform.isAndroid && imageBytes != null) {
      if (kDebugMode) {
        _persistScreenshotsForDebugging(imageBytes);
      }
      FlutterUxcam.sendFrameScreenshot(imageBytes);
      frameNumber += 1;
    }

    print(WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio);
    image.dispose();
    finalImage.dispose();
    
    return imageBytes;
  }

  static Future<Uint8List?> captureAppContent() async {
    if (_instance == null || !_instance!.mounted) return null;
    return await _instance!._captureAppContent();
  }

  List<Rect> _getOcclusionRects(
      RenderRepaintBoundary boundary, double devicePixelRatio) {
    List<Rect> occlusionBounds = [];
    final boxesToOccclude = BoundsTracker.instance.occludedBoxes();
    for (final renderObject in boxesToOccclude) {
      final box = renderObject as RenderBox;
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
    if (_instance == this) {
      _instance = null;
    }
    _screenshotSubscription?.cancel();
    super.dispose();
  }
}
