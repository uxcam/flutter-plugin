import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/smart_events/uxcam_smart_events.dart';

class Uxcam {
    static void registerWith() {                                                                                                                                                                  
      _initIfRecording();                                                                                                                                                                         
    }

    static Future<void> _initIfRecording() async {
      await _waitForBindings();
      try {
        final recording = await const MethodChannel('flutter_uxcam')
            .invokeMethod<bool>('isRecording');
        if (recording == true) {
          UXCamSmartEvents().initialize(enableGestureTracking: true);
        }
      } catch (_) {
        // Not in hybrid mode or native handler not ready
      }
    }

    static Future<void> _waitForBindings() async {
      while (true) {
        try {
          ServicesBinding.instance;
          return;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    } 
}
