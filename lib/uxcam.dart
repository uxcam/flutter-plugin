import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  int? dartTimeStamp;

  UxCam() {
    dartTimeStamp = DateTime.now().millisecondsSinceEpoch;
    const BasicMessageChannel<Object?> _occlusionRectsChannel =
        BasicMessageChannel<Object?>(
      'occlusion_rects_coordinates',
      StandardMessageCodec(),
    );
  }
}
