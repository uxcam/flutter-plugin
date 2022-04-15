import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_occlusion.dart';

class FlutterUxOverlayKeys {
  static const color = "color";
  static const hideGestures = "hideGestures";
}

class FlutterUXOverlay extends FlutterUXOcclusion {


  Color color = Colors.red;
  bool hideGestures = true;

  @override
  String get name => 'UXOcclusionTypeOverlay'; // not used.. only to make it compatible with blur

  @override
  UXOcclusionType get type => UXOcclusionType.overlay;

  @override
  Map<String, dynamic>? get configuration => {
    FlutterUxOverlayKeys.color: [color.red, color.green, color.blue, color.alpha],
    FlutterUxOverlayKeys.hideGestures: hideGestures
  };

  FlutterUXOverlay({
    Color color = Colors.red,
    bool hideGestures = true,
    List<String> screens = const [],
    bool excludeMentionedScreens = false
  }): super(screens, excludeMentionedScreens) {
    this.color = color;
    this.hideGestures = hideGestures;
  }

}