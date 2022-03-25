

import 'package:flutter_uxcam/flutter_occlusion.dart';

class FlutterUxBlurKeys {
  static const blurRadius = "radius";
  static const hideGestures = "hideGestures";
}

enum BlurType {
  gaussian, stack, box, bokeh
}

class FlutterUXBlur extends FlutterUXOcclusion {

  FlutterUXBlur(): super();

  int blurRadius = 10;
  bool hideGestures = false;

  BlurType blurType = BlurType.gaussian;

  @override
  String get name => getName(blurType);

  @override
  UXOcclusionType get type => UXOcclusionType.blur;

  @override
  Map<String, dynamic>? get configuration => {
    FlutterUxBlurKeys.blurRadius: blurRadius,
    FlutterUxBlurKeys.hideGestures: hideGestures
  };

  String getName(BlurType type) {
    switch (type) {
      case BlurType.gaussian: return "gaussianBlur";
      case BlurType.stack: return "stackBlur";
      case BlurType.box: return "boxBlur";
      case BlurType.bokeh: return "bokehBlur";


    }
  }
}

class FlutterUXBlurBuilder extends FlutterUXOcclusionBuilder {

  FlutterUXBlur get _occlusion => occlusion as FlutterUXBlur;

  FlutterUXBlurBuilder() {
    occlusion = FlutterUXBlur();
  }

  void blurRadius(int radius) {
    _occlusion.blurRadius = radius;
  }

  void hideGestures(bool hide) {
    _occlusion.hideGestures = hide;
  }

  FlutterUXBlur build() => _occlusion;
}