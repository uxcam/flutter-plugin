import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

class FlutterUxOverlayKeys {
  static const color = "color";
  static const hideGestures = "hideGestures";
}

class FlutterUXOverlay extends FlutterUXOcclusion {
  Color color = Colors.red;
  bool hideGestures = true;

  int _colorChannel(double value) =>
      (value * 255.0).round().clamp(0, 255).toInt();

  @override
  String get name =>
      'UXOcclusionTypeOverlay'; // not used.. only to make it compatible with blur

  @override
  UXOcclusionType get type => UXOcclusionType.overlay;

  @override
  Map<String, dynamic>? get configuration => {
        FlutterUxOverlayKeys.color: [
          _colorChannel(color.r),
          _colorChannel(color.g),
          _colorChannel(color.b),
          _colorChannel(color.a)
        ],
        FlutterUxOverlayKeys.hideGestures: hideGestures
      };

  FlutterUXOverlay(
      {Color color = Colors.red,
      bool hideGestures = true,
      List<String> screens = const [],
      bool excludeMentionedScreens = false})
      : super(screens, excludeMentionedScreens) {
    this.color = color;
    this.hideGestures = hideGestures;
  }
}
