import 'package:flutter_uxcam/flutter_uxcam.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  int? dartTimeStamp;

  UxCam() {
    dartTimeStamp = DateTime.now().millisecondsSinceEpoch;
  }
}
