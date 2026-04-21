import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/web/js_bridge.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_models.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

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
        OcclusionRegistry.instance.rectFormat = OcclusionPlatform.web;
        registerOcclusionCallback();
        return true;
      case 'logEvent':
        final name = call.arguments['key'] as String;
        _sendEvent(name, {});
        return true;
      case 'setUserIdentity':
        final name = call.arguments['key'] as String;
        _setIdentity(name);
        return true;
      case 'setUserProperty':
        final key = call.arguments['key'] as String;
        final value = call.arguments['value'] as String;
        _setUserProperty(key,value);
        return true;
      case 'setUserProperties':
        final properties = call.arguments['properties'] as Map;
        _setUserProperties(properties.map((k, v) => MapEntry(k, v.toString())));
        return true;
      case 'logEventWithProperties':
        final name = call.arguments['eventName'] as String;
        final properties = Map<String, dynamic>.from(call.arguments['properties'] as Map);
        final stringProps = properties.map((k, v) => MapEntry(k, v.toString()));
        _sendEvent(name, stringProps);
        return true;
      case 'appendGestureContent':
        final x = call.arguments['x'] as double;
        final y = call.arguments['y'] as double;
        final data = Map<String, dynamic>.from(call.arguments['data'] as Map);
        _sendGestureContent(x, y, data);
        return null;
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
  ////websdk-recording.uxcam.com/index.js
  ///http://127.0.0.1:5501/uxcam-websdk-frontend/dist/index.js
  final scriptSrc = '//websdk-recording-stg.uxcam.com/index.js';
    evalJs('''
      window.uxc = {
        __t: [],
        __ak: "$appKey",
        __o: { captureMode: 'flutter' },
        event: function(n, p) { this.__t.push(['event', n, p]); },
        setUserIdentity: function(i) { this.__t.push(['setUserIdentity', i]); },
        setUserProperty: function(k, v) { this.__t.push(['setUserProperty', k, v]); },
        setUserProperties: function(p) { this.__t.push(['setUserProperties', p]); },
        abort: function() { this.__t.push(['abort']); },
        injectOcclusionRects: function(r) { this.__t.push(['injectOcclusionRects', r]); },
        appendGestureContent: function(x, y, d) { this.__t.push(['appendGestureContent', x, y, d]); }
      };
      var head = document.getElementsByTagName('head')[0];
      var script = document.createElement('script');
      script.type = 'text/javascript';
      script.src = '$scriptSrc';
      script.async = true;
      script.defer = true;
      script.id = 'uxcam-web-sdk';
      script.crossOrigin = 'anonymous';
      head.appendChild(script);
    '''
        .toJS);
  }
  
  void _sendEvent(String name, Map<String, String> properties) {
    final _uxc = uxc;
    if (_uxc == null) return;
    uxcEvent(name.toJS, properties.jsify());
  }
  
  void _setIdentity(String name) {
    final _uxc = uxc;
    if (_uxc == null) return;
    uxcSetUserIdentity(name.toJS);
  }
  
  void _setUserProperty(String key, String value) {
    final _uxc = uxc;
    if (_uxc == null) return;
    uxcSetUserProperty(key.toJS, value.toJS);
  }
  
  void _setUserProperties(Map<String, String> properties) {
    final _uxc = uxc;
    if (_uxc == null) return;
    uxcSetUserProperties(properties.jsify());
  }

  void registerOcclusionCallback() {
    final callback = (() {
      final rects = OcclusionRegistry.instance.getOcclusionRects();
      return rects.jsify() as JSArray;
    }).toJS;

    globalContext.setProperty('__uxcam_getOcclusionRects'.toJS, callback);
  }

  void _sendGestureContent(double x, double y, Map<String, dynamic> data) {
    final _uxc = uxc;
    if (_uxc == null) return;
    uxcAppendGestureContent(x, y, data.jsify());
  }

}