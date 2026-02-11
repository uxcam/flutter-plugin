import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@JS('window.uxc')
external JSObject? get _uxc;

/// Web implementation of the FlutterUxcam plugin.
///
/// On web, the UXCam Web SDK (loaded via <script> tag in index.html)
/// handles session recording. This plugin class bridges Dart-side
/// calls to the JS Web SDK so they don't throw MissingPluginException.
class FlutterUxcamWeb {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'flutter_uxcam',
      const StandardMethodCodec(),
      registrar,
    );
    final instance = FlutterUxcamWeb();
    channel.setMethodCallHandler(instance._handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'startWithConfiguration':
      //test event: remove later
        _sendEvent('flutter_plugin_connected', {'source': 'flutter_uxcam_web'});
        return true;
      case 'getPlatformVersion':
        return 'web';
      case 'isRecording':
        return true;
      case 'urlForCurrentSession':
      case 'urlForCurrentUser':
        return null;
      case 'pendingUploads':
        return 0;
      default:
        return null;
    }
  }

  void _sendEvent(String name, Map<String, String> properties) {
    final uxc = _uxc;
    if (uxc == null) return;
    _uxcEvent(name.toJS, properties.jsify());
  }
}

@JS('window.uxc.event')
external void _uxcEvent(JSString name, JSAny? properties);

