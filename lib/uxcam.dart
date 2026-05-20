import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/smart_events/uxcam_smart_events.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';

class Uxcam {
  static const MethodChannel _hybridChannel =
      MethodChannel('uxcam_flutter_plug_hybrid');

  static void registerWith() {
    _ensureHandlerSetup();
  }

  static void _ensureHandlerSetup() {
    try {
      _hybridChannel.setMethodCallHandler(_handlePlugEvents);
    } catch (_) {
      Timer(const Duration(milliseconds: 100), _ensureHandlerSetup);
    }
  }

  static Future<dynamic> _handlePlugEvents(MethodCall call) async {
    switch (call.method) {
      case 'initSmartEvents':
      print("UXHybrid: initSmartEvents received");
        UXCamSmartEvents().initialize(enableGestureTracking: true);
        break;
      case 'initOcclusion':
        OcclusionRegistry.instance;
        break;
      default:
        throw MissingPluginException(
            'No handler for method ${call.method} on channel uxcam_smart_events');
    }
  }
}
