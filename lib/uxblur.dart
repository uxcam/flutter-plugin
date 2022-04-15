

import 'package:flutter_uxcam/flutter_occlusion.dart';

class FlutterUxBlurKeys {
  static const blurRadius = "radius";
  static const hideGestures = "hideGestures";
}

enum BlurType {
  gaussian, stack, box, bokeh
}

class FlutterUXBlur extends FlutterUXOcclusion {

  int blurRadius = 10;
  bool hideGestures = true;

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

  FlutterUXBlur({
    int blurRadius = 10,
    BlurType blurType = BlurType.gaussian,
    bool hideGestures = true,
    List<String> screens = const [],
    bool excludeMentionedScreens = false
  }): super(screens, excludeMentionedScreens) {
    this.blurRadius = blurRadius;
    this.blurType = blurType;
    this.hideGestures = hideGestures;
  }

  String getName(BlurType type) {
    switch (type) {
      case BlurType.gaussian: return "gaussianBlur";
      case BlurType.stack: return "stackBlur";
      case BlurType.box: return "boxBlur";
      case BlurType.bokeh: return "bokehBlur";


    }
  }
}