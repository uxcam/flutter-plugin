import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_occlusion.dart';

class FlutterUxOverlayKeys {
  static const color = "color";
  static const hideGestures = "hideGestures";
}

class FlutterUXOverlay extends FlutterUXOcclusion {


  Color color = Colors.red;
  bool hideGestures = false;

  @override
  String get name => 'UXOcclusionTypeOverlay'; // not used.. only to make it compatible with blur

  @override
  UXOcclusionType get type => UXOcclusionType.overlay;

  @override
  Map<String, dynamic>? get configuration => {
    FlutterUxOverlayKeys.color: [color.red, color.green, color.blue, color.alpha],
    FlutterUxOverlayKeys.hideGestures: hideGestures
  };

}

class FlutterUXOverlayBuilder extends FlutterUXOcclusionBuilder {

  FlutterUXOverlay get _occlusion => occlusion as FlutterUXOverlay;

  FlutterUXOverlayBuilder() {
    occlusion = FlutterUXOverlay();
  }

  void color(Color color) {
    _occlusion.color = color;
  }

  void hideGestures(bool hide) {
    _occlusion.hideGestures = hide;
  }

  FlutterUXOverlay build() => _occlusion;
}