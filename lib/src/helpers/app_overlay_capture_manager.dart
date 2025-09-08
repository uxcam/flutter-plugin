import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Singleton manager that holds a global RepaintBoundary for full app capture
class AppOverlayCaptureManager {
  AppOverlayCaptureManager._internal();

  static final AppOverlayCaptureManager _instance =
      AppOverlayCaptureManager._internal();

  factory AppOverlayCaptureManager() => _instance;

  final GlobalKey _rootBoundaryKey = GlobalKey(debugLabel: 'uxcam_root_boundary');

  GlobalKey get rootBoundaryKey => _rootBoundaryKey;

  /// Capture the current frame of the app as ui.Image.
  ///
  /// If [devicePixelRatio] is not provided, it uses the first view's DPR.
  Future<ui.Image?> captureImage({double? devicePixelRatio}) async {
    final context = _rootBoundaryKey.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    try {
      // Try to synchronize with the current frame end for a stable image
      try {
        await WidgetsBinding.instance.endOfFrame
            .timeout(const Duration(milliseconds: 50));
      } catch (_) {}

      final double dpr = devicePixelRatio ?? ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      final ui.Image image = await renderObject.toImage(pixelRatio: dpr);
      return image;
    } catch (_) {
      return null;
    }
  }

  /// Capture the current frame of the app to PNG (or other) bytes
  Future<Uint8List?> captureBytes({
    double? devicePixelRatio,
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  }) async {
    final image = await captureImage(devicePixelRatio: devicePixelRatio);
    if (image == null) return null;
    final ByteData? byteData = await image.toByteData(format: format);
    return byteData?.buffer.asUint8List();
  }
}

