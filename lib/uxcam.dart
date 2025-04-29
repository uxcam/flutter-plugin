import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_manager.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final OcclusionManager _manager = OcclusionManager();
  int? dartTimeStamp;

  UxCam() {
    dartTimeStamp = DateTime.now().millisecondsSinceEpoch;
    const BasicMessageChannel<Object?> _occlusionRectsChannel =
        BasicMessageChannel<Object?>(
      'occlusion_rects_coordinates',
      StandardMessageCodec(),
    );
    _occlusionRectsChannel.setMessageHandler((event) async {
      if (event is int) {
        return dartTimeStamp;
      }
      return "[]";
    });
  }
}
