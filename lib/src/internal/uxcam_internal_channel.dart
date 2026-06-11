import 'package:flutter/services.dart';

class UXCamInternal {
  UXCamInternal._();

  static const MethodChannel _channel = MethodChannel('flutter_uxcam');

  static void Function(String name, Map<String, dynamic>? data)? debugSink;

  static void send(String name, [Map<String, dynamic>? data]) {
    final sink = debugSink;
    if (sink != null) {
      sink(name, data);
      return;
    }
    
    try {
      _channel
          .invokeMethod('uxcamInternalEvent', {'name': name, 'data': data})
          .catchError((Object _) => null);
    } catch (_) {}
  }
}
