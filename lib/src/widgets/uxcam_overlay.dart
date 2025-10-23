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
  GlobalKey scr = GlobalKey();
  final eventChannel = EventChannel('screenshot_event');
  StreamSubscription? _screenshotSubscription;

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
      key: scr,
    );
  }

  captureAppContent() async {
    final boundary =
        scr.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final image = await boundary?.toImage();
    final byteData = await image?.toByteData(format: ImageByteFormat.png);
    final imageBytes = byteData?.buffer.asUint8List();

    if (imageBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          await File('${directory.path}/container_image.png').create();
      await imagePath.writeAsBytes(imageBytes);
    }
  }

  @override
  void dispose() {
    _screenshotSubscription?.cancel();
    super.dispose();
  }
}
