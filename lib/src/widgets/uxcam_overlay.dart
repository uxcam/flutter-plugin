import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
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
      captureAppContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: widget.child,
      key: rootViewkey,
    );
  }

  captureAppContent() async {
    final boundary = rootViewkey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    final image = await boundary?.toImage();
    final byteData = await image?.toByteData(format: ImageByteFormat.png);
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

  @override
  void dispose() {
    _screenshotSubscription?.cancel();
    super.dispose();
  }
}
