import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Platform plugin implementation registered by Flutter tooling.
class FlutterUxcamWeb {
  String? _appKey;
  Map<String, dynamic>? _configuration;
  bool _overallOptedIn = true;
  bool _videoOptedIn = true;
  bool _multiSessionRecord = false;

  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'flutter_uxcam',
      const StandardMethodCodec(),
      registrar,
    );
    channel.setMethodCallHandler(FlutterUxcamWeb().handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    final args = _args(call);

    switch (call.method) {
      case 'getPlatformVersion':
        return 'Web';
      case 'startWithConfiguration':
        return _startWithConfiguration(args['config']);
      case 'startWithKey':
        return _start(args['key'] as String?);
      case 'configurationForUXCam':
        return _configuration ?? {'userAppKey': _appKey ?? ''};
      case 'updateConfiguration':
        _configuration = _stringKeyedMap(args['config']);
        return true;
      case 'logEvent':
        _logEvent(args['key'] as String?, const {});
        return null;
      case 'logEventWithProperties':
        _logEvent(
          args['eventName'] as String?,
          _stringKeyedMap(args['properties']),
        );
        return null;
      case 'setUserIdentity':
        _setUserIdentity(args['key'] as String?);
        return null;
      case 'setUserProperty':
        _setUserProperty(args['key'] as String?, args['value']);
        return null;
      case 'appendGestureContent':
        _appendGestureContent(args);
        return null;
      case 'isRecording':
        return _appKey != null;
      case 'optInOverall':
        _overallOptedIn = true;
        return null;
      case 'optOutOverall':
        _overallOptedIn = false;
        return null;
      case 'optInOverallStatus':
        return _overallOptedIn;
      case 'optIntoVideoRecording':
        _videoOptedIn = true;
        return null;
      case 'optOutOfVideoRecording':
        _videoOptedIn = false;
        return null;
      case 'optInVideoRecordingStatus':
        return _videoOptedIn;
      case 'setMultiSessionRecord':
        _multiSessionRecord = args['key'] == true;
        return null;
      case 'getMultiSessionRecord':
        return _multiSessionRecord;
      case 'setAutomaticScreenNameTagging':
        return null;
      case 'pendingUploads':
        return 0;
      case 'urlForCurrentUser':
      case 'urlForCurrentSession':
        return null;
      case 'applyOcclusion':
      case 'removeOcclusion':
        return false;
      case 'optInSchematicRecordingStatus':
        return false;
      case 'attachBridge':
      case 'startNewSession':
      case 'addNewRect':
      case 'stopSessionAndUploadData':
      case 'occludeSensitiveScreen':
      case 'occludeSensitiveScreenWithoutGesture':
      case 'occludeAllTextView':
      case 'occludeAllTextFields':
      case 'tagScreenName':
      case 'setSessionProperty':
      case 'pauseScreenRecording':
      case 'resumeScreenRecording':
      case 'optIntoSchematicRecordings':
      case 'optOutOfSchematicRecordings':
      case 'cancelCurrentSession':
      case 'allowShortBreakForAnotherApp':
      case 'allowShortBreakForAnotherAppWithDuration':
      case 'resumeShortBreakForAnotherApp':
      case 'deletePendingUploads':
      case 'uploadPendingSession':
      case 'stopApplicationAndUploadData':
      case 'addScreenNameToIgnore':
      case 'removeScreenNameToIgnore':
      case 'removeAllScreenNamesToIgnore':
      case 'setPushNotificationToken':
      case 'reportBugEvent':
      case 'reportExceptionEvent':
      case 'occludeRectWithCoordinates':
      case 'addFrameData':
      case 'registerEngine':
        return null;
      default:
        return null;
    }
  }

  Map<dynamic, dynamic> _args(MethodCall call) {
    final arguments = call.arguments;
    if (arguments is Map) return arguments;
    return const {};
  }

  bool _startWithConfiguration(Object? config) {
    _configuration = _stringKeyedMap(config);
    return _start(_configuration?['userAppKey'] as String?);
  }

  bool _start(String? appKey) {
    if (appKey == null || appKey.isEmpty) return false;
    if (_appKey != null) return true;

    _appKey = appKey;
    _injectWebSdk(appKey);
    _registerOcclusionCallback();
    return true;
  }

  void _injectWebSdk(String appKey) {
    final document = globalContext['document'] as JSObject;
    final existing =
        document.callMethod('getElementById'.toJS, 'uxcam-web-sdk'.toJS);
    if (!existing.isUndefinedOrNull) return;

    final queue = <JSAny?>[].toJS;
    final queuedUxc = <String, dynamic>{
      '__t': queue,
      '__ak': appKey,
      '__o': {'captureMode': 'flutter'},
    }.jsify() as JSObject;

    void push(List<JSAny?> entry) {
      queue.callMethod('push'.toJS, entry.toJS);
    }

    queuedUxc['event'] = ((JSAny? name, JSAny? properties) {
      push(['event'.toJS, name, properties]);
    }).toJS;
    queuedUxc['setUserIdentity'] = ((JSAny? identity) {
      push(['setUserIdentity'.toJS, identity]);
    }).toJS;
    queuedUxc['setUserProperty'] = ((JSAny? key, JSAny? value) {
      push(['setUserProperty'.toJS, key, value]);
    }).toJS;
    queuedUxc['appendGestureContent'] = ((JSAny? x, JSAny? y, JSAny? data) {
      push(['appendGestureContent'.toJS, x, y, data]);
    }).toJS;

    globalContext['uxc'] = queuedUxc;

    final script =
        document.callMethod('createElement'.toJS, 'script'.toJS) as JSObject;
    script['id'] = 'uxcam-web-sdk'.toJS;
    script['type'] = 'text/javascript'.toJS;
    script['src'] = 'https://websdk-recording.uxcam.com/index.js'.toJS;
    script['async'] = true.toJS;
    script['defer'] = true.toJS;
    script['crossOrigin'] = 'anonymous'.toJS;
    script['onerror'] = ((JSAny? event) {
      // ignore: avoid_print
      print('UXCam: failed to load web SDK script');
    }).toJS;

    final head = document['head'] as JSObject?;
    head?.callMethod('appendChild'.toJS, script);
  }

  void _registerOcclusionCallback() {
    final callback = (() {
      final rects = OcclusionRegistry.instance.getOcclusionRects();
      final jsified = rects.jsify();
      if (jsified is JSArray) return jsified;
      return <JSAny?>[].toJS;
    }).toJS;
    globalContext['__uxcam_getOcclusionRects'] = callback;
  }

  void _logEvent(String? name, Map<String, dynamic> properties) {
    final uxc = _uxc;
    if (name == null || name.isEmpty || uxc == null) return;
    uxc.callMethod('event'.toJS, name.toJS, properties.jsify());
  }

  void _setUserIdentity(String? identity) {
    final uxc = _uxc;
    if (identity == null || identity.isEmpty || uxc == null) return;
    uxc.callMethod('setUserIdentity'.toJS, identity.toJS);
  }

  void _setUserProperty(String? key, Object? value) {
    final uxc = _uxc;
    if (key == null || key.isEmpty || value == null || uxc == null) return;
    uxc.callMethod('setUserProperty'.toJS, key.toJS, value.toString().toJS);
  }

  void _appendGestureContent(Map<dynamic, dynamic> args) {
    final uxc = _uxc;
    if (uxc == null) return;
    final x = args['x'];
    final y = args['y'];
    if (x is! num || y is! num) return;
    uxc.callMethod(
      'appendGestureContent'.toJS,
      x.toDouble().toJS,
      y.toDouble().toJS,
      _stringKeyedMap(args['data']).jsify(),
    );
  }

  JSObject? get _uxc {
    final value = globalContext['uxc'];
    if (value.isUndefinedOrNull) return null;
    return value as JSObject;
  }

  Map<String, dynamic> _stringKeyedMap(Object? value) {
    if (value is! Map) return {};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}
