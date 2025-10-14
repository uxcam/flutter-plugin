import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final _uxcamChannel = BasicMessageChannel<Object>(
    'uxcam_message_channel',
    StringCodec(),
  );

  UxCam() {
    _uxcamChannel.setMessageHandler((message) async {
      if (message is String && message == 'initialize') {
        OcclusionWrapperManager().continueUpdate(true);
        OcclusionWrapperManager().initialize();
      }
      if (message is String && message == 'stop') {
        OcclusionWrapperManager().continueUpdate(false);
        OcclusionWrapperManager().stop();
      }
      return "true";
    });
  }
}
