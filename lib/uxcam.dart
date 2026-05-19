import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/smart_events/uxcam_smart_events.dart';

class Uxcam {
  static const MethodChannel _smartEventsChannel =
      MethodChannel('uxcam_smart_events');

  static void registerWith() {
    _ensureHandlerSetup();
  }

  static void _ensureHandlerSetup() {
    try {
      _smartEventsChannel.setMethodCallHandler(_handleSmartEvents);
    } catch (_) {
      Timer(const Duration(milliseconds: 100), _ensureHandlerSetup);
    }
  }

  static Future<dynamic> _handleSmartEvents(MethodCall call) async {
    switch (call.method) {
      case 'initSmartEvents':
        UXCamSmartEvents().initialize(enableGestureTracking: true);
        break;
      default:
        throw MissingPluginException(
            'No handler for method ${call.method} on channel uxcam_smart_events');
    }
  }
}
