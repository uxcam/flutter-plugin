import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';

class UxCam {
  int _frameCount = 0;
  int _referenceFrameCount = 0;
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final _uxcamChannel = BasicMessageChannel<Object>(
    'uxcam_message_channel',
    StringCodec(),
  );

  UxCam() {
    _startFrameTimingUpdate();
    _uxcamChannel.setMessageHandler((message) async {
      if (message is String && message == 'initialize') {
        _referenceFrameCount = _frameCount;
        OcclusionWrapperManager().initialize();
      }
      if (message is String && message == 'stop') {
        if (_referenceFrameCount == _frameCount) {
          OcclusionWrapperManager().stop();
          print("frame is stable: safe");
        } else {
          print("frame is unstable: not safe");
          return "false";
        }
      }
      return "true";
    });
  }

  void _startFrameTimingUpdate() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameCount++;
      _startFrameTimingUpdate();
    });
  }
}
