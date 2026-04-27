import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/web/js_bridge.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_models.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the FlutterUxcam plugin.
///
/// On web, the UXCam Web SDK (loaded via <script> tag in index.html)
/// handles session recording. This plugin class bridges Dart-side
/// calls to the JS Web SDK so they don't throw MissingPluginException.
class FlutterUxcamWeb {
  String? _initializedAppKey;

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

        if (_initializedAppKey != null) {
          if (_initializedAppKey == appKey) {
            // Already initialized with this key — idempotent no-op.
            return true;
          }
          // Different key — programming error. Don't silently reconfigure.
          // ignore: avoid_print
          print('[UXCam] startWithConfiguration called again with a different '
              'app key. Ignoring — reconfiguration mid-session is not '
              'supported. Call stopSession first if you need to switch keys.');
          return true;
        }
        _ensurePathUrlStrategy();
        _initializedAppKey = appKey;
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
      case 'abort':
        _abort();
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

  if (web.document.getElementById('uxcam-web-sdk') != null) {
    return;
  }

  ////websdk-recording.uxcam.com/index.js
  ///http://127.0.0.1:5501/uxcam-websdk-frontend/dist/index.js
  final scriptSrc = 'https://websdk-recording-stg.uxcam.com/index.js';

  final uxc = <String, dynamic> {
    '__t': [],
    '__ak': appKey,
    '__o': { 'captureMode': 'flutter' },
  }.jsify() as JSObject;

    final queue = uxc['__t'] as JSArray;

    void push(List<JSAny?> entry) {
      queue.callMethod('push'.toJS, entry.toJS);
    }

    uxc['event'] = ((JSAny? n, JSAny? p) {
      push(['event'.toJS, n, p]);
    }).toJS;

    uxc['setUserIdentity'] = ((JSAny? i) {
      push(['setUserIdentity'.toJS, i]);
    }).toJS;

    uxc['setUserProperty'] = ((JSAny? k, JSAny? v) {
      push(['setUserProperty'.toJS, k, v]);
    }).toJS;

    uxc['setUserProperties'] = ((JSAny? p) {
      push(['setUserProperties'.toJS, p]);
    }).toJS;

    uxc['injectOcclusionRects'] = ((JSAny? p) {
      push(['injectOcclusionRects'.toJS, p]);
    }).toJS;

    uxc['appendGestureContent'] = ((JSAny? x, JSAny? y, JSAny? z) {
      push(['appendGestureContent'.toJS, x, y, z]);
    }).toJS;

    uxc['abort'] = (() {
      push(['abort'.toJS]);
    }).toJS;

    // Publish on window.
    globalContext['uxc'] = uxc;

    // 2. Insert the SDK <script> via the DOM API.
    final script = web.HTMLScriptElement()
      ..type = 'text/javascript'
      ..src = scriptSrc
      ..async = true
      ..defer = true
      ..id = 'uxcam-web-sdk'
      ..crossOrigin = 'anonymous';
    web.document.head?.appendChild(script);

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

  void _abort() {
    final _uxc = uxc;
    if (_uxc == null) return;
    uxcAbort();
  }

  void _ensurePathUrlStrategy() {
  if (!kIsWeb) return;
  if (urlStrategy == null) {
    usePathUrlStrategy();
  }
}

}