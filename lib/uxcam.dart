import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/smart_events/uxcam_smart_events.dart';

class Uxcam {
    //registerWith() runs before the engine has fully set up PlatformDispatcher._initialLifecycleState.
    //sendPlatformMessage operates at the dart:ui layer talking directly to the engine's message passing system without going through ServicesBinding 
    //The await on the response naturally defers UXCamSmartEvents().initialize() until after main() has run and bindings are ready
    static void registerWith() {
      _initIfRecording();
    }

    static Future<void> _initIfRecording() async {
      try {
        const codec = StandardMethodCodec();
        final completer = Completer<ByteData?>();
        ui.PlatformDispatcher.instance.sendPlatformMessage(
          'flutter_uxcam',
          codec.encodeMethodCall(const MethodCall('isRecording')),
          (ByteData? reply) => completer.complete(reply),
        );
        final reply = await completer.future;
        if (reply != null && codec.decodeEnvelope(reply) == true) {
          UXCamSmartEvents().initialize(enableGestureTracking: true);
        }
      } catch (_) {
        // Not in hybrid mode or native handler not ready
      }
    }
}
