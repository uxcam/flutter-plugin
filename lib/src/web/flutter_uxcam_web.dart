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
        final config = call.arguments['config'] as Map;
        final appKey = config['userAppKey'] as String;
        _injectWebSdk(appKey);

        //final _ = FlutterWebRegistry.instance;
        
        //test event: remove later
        //_sendEvent('flutter_plugin_connected', {'source': 'flutter_uxcam_web', 'version':'1.0.1'});
        return true;
      case 'logEvent':
        final name = call.arguments['key'] as String;
        _sendEvent(name, {});
        return true;
      case 'logEventWithProperties':
        final name = call.arguments['eventName'] as String;
        final properties = Map<String, dynamic>.from(call.arguments['properties'] as Map);
        final stringProps = properties.map((k, v) => MapEntry(k, v.toString()));
        _sendEvent(name, stringProps);
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

  void _injectWebSdk(String appKey) {
    _evalJs('''
      window.uxc = {
        __t: [],
        __ak: "$appKey",
        __o: {},
        event: function(n, p) { this.__t.push(['event', n, p]); },
        setUserIdentity: function(i) { this.__t.push(['setUserIdentity', i]); },
        setUserProperty: function(k, v) { this.__t.push(['setUserProperty', k, v]); },
        setUserProperties: function(p) { this.__t.push(['setUserProperties', p]); },
        abort: function() { this.__t.push(['abort']); }
      };
      var head = document.getElementsByTagName('head')[0];
      var script = document.createElement('script');
      script.type = 'text/javascript';
      script.src = '//websdk-recording.uxcam.com/index.js';
      script.async = true;
      script.defer = true;
      script.id = 'uxcam-web-sdk';
      script.crossOrigin = 'anonymous';
      head.appendChild(script);
    '''.toJS);
  }

  void _sendEvent(String name, Map<String, String> properties) {
    final uxc = _uxc;
    if (uxc == null) return;
    _uxcEvent(name.toJS, properties.jsify());
  }
}

@JS('window.uxc.event')
external void _uxcEvent(JSString name, JSAny? properties);

@JS('eval')
external void _evalJs(JSString code);