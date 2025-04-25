import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/channel_callback.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';
import 'package:stack_trace/stack_trace.dart';

class FlutterUxcam {
  static const MethodChannel _channel = const MethodChannel('flutter_uxcam');

  static UxCam? uxCam;

  /// For getting platformVersion from Native Side.
  static Future<String> get platformVersion async {
    final String? version =
        await _channel.invokeMethod<String>('getPlatformVersion');
    return version!;
  }

  /// This method is used to as a starting point for configuring and
  /// starting point for setting up UXCam SDK.
  ///
  /// [config] is a FlutterUxConfig Object
  ///
  /// * [FlutterUxConfig](https://pub.dev/documentation/flutter_uxcam/latest/uxcam/FlutterUxConfig-class.html)
  static Future<bool> startWithConfiguration(FlutterUxConfig config) async {
    uxCam = UxCam();
    ChannelCallback.handleChannelCallBacks(_channel);

    final bool? status = await _channel.invokeMethod<bool>(
        'startWithConfiguration', {"config": config.toJson()});

    return status!;
  }

  /// This call is available only for IOS portion of the SDK so not sure will work on Android.
  static Future<FlutterUxConfig> configurationForUXCam() async {
    final Map<String, dynamic>? json =
        await _channel.invokeMapMethod('configurationForUXCam');
    return FlutterUxConfig.fromJson(json!);
  }

  /// This call is available only for IOS portion of the SDK so not sure will work on Android.
  static Future<bool> updateConfiguration(FlutterUxConfig config) async {
    final bool? status = await _channel
        .invokeMethod<bool>('updateConfiguration', {"config": config.toJson()});
    return status!;
  }

  /// Older implementation of starting UXCam SDK
  ///
  /// [key] is String
  @Deprecated('Use `startWithConfiguration`')
  static Future<bool> startWithKey(String key) async {
    final bool? status =
        await _channel.invokeMethod<bool>('startWithKey', {"key": key});
    return status!;
  }

  /// This method is used for starting new session
  static Future<void> startNewSession() async {
    await _channel.invokeMethod('startNewSession');
  }

  /// This method is used add a new rect that needs to be tracked
  static Future<void> addNewRect() async {
    await _channel.invokeMethod('addNewRect');
  }

  /// This method is used for stopping the current session
  /// and uploading the data to server
  static Future<void> stopSessionAndUploadData() async {
    await _channel.invokeMethod('stopSessionAndUploadData');
  }

  /// This method is used with parameter to occlude following screen
  ///
  /// [hideScreen] is boolean value.
  ///
  /// eg: occludeSensitiveScreen(true);  ---> will hide
  /// eg: occludeSensitiveScreen(false);  ---> will unhide if hidden
  static Future<void> occludeSensitiveScreen(bool hideScreen) async {
    await _channel.invokeMethod('occludeSensitiveScreen', {"key": hideScreen});
  }

  /// This method is used with parameter to occlude following screen
  /// and prevent from registering Gestures.
  ///
  /// [hideScreen] is boolean value.
  ///
  /// eg: occludeSensitiveScreenWithoutGesture(true);  ---> will hide
  /// eg: occludeSensitiveScreenWithoutGesture(false);  ---> will unhide if hidden
  static Future<void> occludeSensitiveScreenWithoutGesture(
      bool hideScreen) async {
    await _channel.invokeMethod('occludeSensitiveScreenWithoutGesture',
        {"key": hideScreen, "withoutGesture": true});
  }

  /// This method is used for hiding TextField
  ///
  /// [value] is boolean.
  @Deprecated('Use `occludeAllTextFields`')
  static Future<void> occludeAllTextView(bool value) async {
    await _channel.invokeMethod('occludeAllTextView', {"key": value});
  }

  /// This method is used for hiding all TextFields
  ///
  /// [value] is boolean.
  static Future<void> occludeAllTextFields(bool value) async {
    await _channel.invokeMethod('occludeAllTextFields', {"key": value});
  }

  /// This method is used for tagging Screen with custom names
  ///
  /// [screenName] is String.
  ///
  /// Name to be displayed in Dashboard
  /// By Default this is done automatically
  /// the name field specified in Route will be considered as screenName
  ///
  /// * See: [Flutter Tagging Approach](https://developer.uxcam.com/docs/flutter-tagging-approach)
  static Future<void> tagScreenName(String screenName) async {
    await _channel.invokeMethod('tagScreenName', {"key": screenName});
  }

  /// This method is used for setting the UserIdentity that can be
  /// seen as sessions.
  ///
  /// [userIdentity] is String
  ///
  /// By default if this is not set. A Random name will be assigned.
  static Future<void> setUserIdentity(String? userIdentity) async {
    await _channel.invokeMethod('setUserIdentity', {"key": userIdentity});
  }

  /// This method is used for setting more user Properties that will be present
  /// and also unique to that user.
  ///
  /// [key] is String
  /// [value] is String
  ///
  /// eg: setUserProperty('username', 'john')
  static Future<void> setUserProperty(String key, String value) async {
    await _channel
        .invokeMethod('setUserProperty', {"key": key, "value": value});
  }

  /// This method is used for setting properties that will be specific to
  /// that session
  ///
  /// [key] is String
  /// [value] is String
  ///
  /// eg: setUserProperty('username', 'john')
  static Future<void> setSessionProperty(String key, String value) async {
    await _channel
        .invokeMethod('setSessionProperty', {"key": key, "value": value});
  }

  /// This method is used for sending event to be logged.
  ///
  /// [logEvent] is String
  ///
  /// Here logEvent is sending the value as trigger
  static Future<void> logEvent(String logEvent) async {
    await _channel.invokeMethod('logEvent', {"key": logEvent});
  }

  /// This method is used for sending event to be logged.
  ///
  /// [logEvent] is String
  ///
  /// [properties] Map<String, dynamic>
  ///
  /// Here logEvent is sending the value with additional data.
  static Future<void> logEventWithProperties(
      String eventName, Map<String, dynamic> properties) async {
    await _channel.invokeMethod('logEventWithProperties',
        {"eventName": eventName, "properties": properties});
  }

  /// This method is used for verifying if the recording is currently active
  static Future<bool> isRecording() async {
    final bool? starter = await _channel.invokeMethod<bool>('isRecording');
    return starter!;
  }

  /// This method is used for pausing the current session video recording
  static Future<void> pauseScreenRecording() async {
    await _channel.invokeMethod('pauseScreenRecording');
  }

  /// This method is used for resuming the current session video recording
  static Future<void> resumeScreenRecording() async {
    await _channel.invokeMethod('resumeScreenRecording');
  }

  /// This method is used for opting in to enable recording at runtime
  static Future<void> optInOverall() async {
    await _channel.invokeMethod('optInOverall');
  }

  /// This method is used for opting in to disable recording at runtime
  static Future<void> optOutOverall() async {
    await _channel.invokeMethod('optOutOverall');
  }

  /// This method is used for opting in to enable recording at runtime
  /// This will return boolean for status
  static Future<bool> optInOverallStatus() async {
    final bool? optStatus =
        await _channel.invokeMethod<bool>('optInOverallStatus');
    return optStatus!;
  }

  /// This method is used for opting in to enable video recording at runtime
  static Future<void> optIntoVideoRecording() async {
    await _channel.invokeMethod('optIntoVideoRecording');
  }

  /// This method is used for opting in to disable video recording at runtime
  static Future<void> optOutOfVideoRecording() async {
    await _channel.invokeMethod('optOutOfVideoRecording');
  }

  /// This method is used for opting in to enable video recording at runtime
  /// This will return boolean for status
  static Future<bool> optInVideoRecordingStatus() async {
    final bool? optStatus =
        await _channel.invokeMethod<bool>('optInVideoRecordingStatus');
    return optStatus!;
  }

  /// This method is used for opting in to enable video recording at runtime
  /// This call is required for enabling video recording permission in IOS
  ///
  /// This should be added before starting with configuration
  /// Else the video will not be recorded for IOS.
  ///
  /// * See: [Flutter UXCam Developer Documentation](https://developer.uxcam.com/docs/flutter)
  ///
  /// NOTE: This will only work on IOS
  static Future<void> optIntoSchematicRecordings() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('optIntoSchematicRecordings');
    }
  }

  /// This method is specifically for IOS to opt out of video recording
  /// NOTE: This will not work for Android
  static Future<void> optOutOfSchematicRecordings() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('optOutOfSchematicRecordings');
    }
  }

  /// This method is same as `optIntoSchematicRecordings()` but will return boolean
  /// for status.
  ///
  /// NOTE: This will not work for Android. This will return false.
  static Future<bool> optInSchematicRecordingStatus() async {
    if (Platform.isIOS) {
      final bool? optStatus =
          await _channel.invokeMethod<bool>('optInSchematicRecordingStatus');
      return optStatus!;
    }
    return false;
  }

  /// This method is used for cancelling current running session.
  static Future<void> cancelCurrentSession() async {
    await _channel.invokeMethod('cancelCurrentSession');
  }

  /// This method is used for pausing session when navigating to another app
  ///
  /// [continueSession] is boolean
  ///
  /// eg: allowShortBreakForAnotherApp(true) ---> will stop session until user
  /// comes back to app. Current Session will not be stopped.
  static Future<void> allowShortBreakForAnotherApp(bool continueSession) async {
    await _channel
        .invokeMethod('allowShortBreakForAnotherApp', {"key": continueSession});
  }

  /// Pausing Screen Recording by adding Occlusion for screen passing duration
  /// parameter.
  ///
  /// [duration] is timeInMillisecond.
  ///
  /// eg: FlutterUXCam.allowShortBreakWithMaxDuration(4000) meaning 4 seconds.
  ///
  /// Note: JUST FOR Android - Time to wait before closing current session.
  /// By default the method will wait 180000ms (3 min) to end the session.
  static Future<void> allowShortBreakForAnotherAppWithDuration(
      int duration) async {
    await _channel.invokeMethod(
        'allowShortBreakForAnotherAppWithDuration', {"duration": duration});
  }

  /// This method is used to set multiSessionRecord feature
  ///
  /// [multiSessionRecord] is boolean
  static Future<void> setMultiSessionRecord(bool multiSessionRecord) async {
    await _channel
        .invokeMethod('setMultiSessionRecord', {"key": multiSessionRecord});
  }

  /// This will return value for multiSessionRecord status as boolean
  static Future<bool> getMultiSessionRecord() async {
    final bool? value =
        await _channel.invokeMethod<bool>('getMultiSessionRecord');
    return value!;
  }

  /// This will tell SDK to automatically Tag Screen or not.
  ///
  /// [enable] is boolean
  ///
  /// * See: [Flutter Tagging Approach](https://developer.uxcam.com/docs/flutter-tagging-approach)
  static Future<void> setAutomaticScreenNameTagging(bool enable) async {
    await _channel
        .invokeMethod('setAutomaticScreenNameTagging', {"key": enable});
  }

  /// This method is used for resuming session after the app navigated back
  ///
  /// Used in conjunction with `allowShortBreakForAnotherApp`
  static Future<void> resumeShortBreakForAnotherApp() async {
    await _channel.invokeMethod('resumeShortBreakForAnotherApp');
  }

  /// This method is used for deleting all the pending Session that is
  /// not uploaded.
  static Future<void> deletePendingUploads() async {
    await _channel.invokeMethod('deletePendingUploads');
  }

  /// This method is used getting number of upload counts
  static Future<int> pendingUploads() async {
    final int? count = await _channel.invokeMethod<int>('pendingUploads');
    return count!;
  }

  /// This method is used for performing manual trigger for uploading sessions that
  /// are not uploaded.
  static Future<void> uploadPendingSession() async {
    await _channel.invokeMethod('uploadPendingSession');
  }

  @Deprecated("Please use stopSessionAndUploadData() instead")
  static Future<void> stopApplicationAndUploadData() async {
    await _channel.invokeMethod('stopApplicationAndUploadData');
  }

  /// This method will return url for current user
  static Future<String?> urlForCurrentUser() async {
    final String? url =
        await _channel.invokeMethod<String>('urlForCurrentUser');
    return url;
  }

  /// This method will return url for current session to be uploaded
  static Future<String?> urlForCurrentSession() async {
    final String? url =
        await _channel.invokeMethod<String>('urlForCurrentSession');
    return url;
  }

  /// This method is used for adding screen Names to be ignored for occlusion
  static Future<void> addScreenNameToIgnore(String screenName) async {
    await _channel.invokeMethod('addScreenNameToIgnore', {"key": screenName});
  }

  /// This method is used for removing screen Names to be ignored for occlusion
  static Future<void> removeScreenNameToIgnore(String screenName) async {
    await _channel
        .invokeMethod('removeScreenNameToIgnore', {"key": screenName});
  }

  /// This method is used for removing all the registered screenNames that needs
  /// to be ignored.
  static Future<void> removeAllScreenNamesToIgnore() async {
    await _channel.invokeMethod('removeAllScreenNamesToIgnore');
  }

  static Future<void> setPushNotificationToken(String token) async {
    await _channel.invokeMethod('setPushNotificationToken', {"key": token});
  }

  /// This method is used for sending any report as Bug as key value pair
  static Future<void> reportBugEvent(String eventName,
      [Map<String, dynamic>? properties]) async {
    await _channel.invokeMethod(
        'reportBugEvent', {"eventName": eventName, "properties": properties});
  }

  /// This method is used for sending any report as Bug as key value pair
  static Future<void> reportExceptionEvent(
    dynamic exception,
    StackTrace? stack,
  ) async {
    final StackTrace stackTrace = (stack == null || stack.toString().isEmpty)
        ? StackTrace.current
        : stack;

    final List<Map<String, String>> stackTraceElements =
        getStackTraceElements(stackTrace);

    await _channel.invokeMethod('reportExceptionEvent', {
      "exception": exception.toString(),
      "stackTraceElements": stackTraceElements,
    });
  }

  /// This method is used for applying occlusion (or Blur) settings
  static Future<bool> applyOcclusion(FlutterUXOcclusion occlusion) async {
    final bool? status = await _channel.invokeMethod<bool>(
        'applyOcclusion', {"occlusion": occlusion.toJson()});
    return status!;
  }

  /// This method is used for remove occlusion (or Blur) with specified settings
  static Future<bool> removeOcclusion(FlutterUXOcclusion occlusion) async {
    final bool? status = await _channel.invokeMethod<bool>(
        'removeOcclusion', {"occlusion": occlusion.toJson()});
    return status!;
  }

  /// Here the coordinates are the location of the view/enclosing box
  /// x0 - topLeft, y0 - topLeft
  /// x1 - bottomRight, y1 - bottomRight
  /// The Coordinates are similar to normal graph plotting
  static Future<void> occludeRectWithCoordinates(
      int x0, int y0, int x1, int y1) async {
    await _channel.invokeMethod<void>("occludeRectWithCoordinates", {
      "x0": x0,
      "y0": y0,
      "x1": x1,
      "y1": y1,
    });
  }

  static Future<void> addFrameData(int timestamp, String frameData) async {
    await _channel.invokeMethod<void>("addFrameData", {
      "timestamp": timestamp,
      "frameData": frameData,
    });
  }
}

List<Map<String, String>> getStackTraceElements(StackTrace stackTrace) {
  final Trace trace = Trace.parseVM(stackTrace.toString()).terse;
  final List<Map<String, String>> elements = <Map<String, String>>[];

  for (final Frame frame in trace.frames) {
    final Map<String, String> element = <String, String>{
      'file': frame.library,
      'line': frame.line?.toString() ?? '0',
    };
    final String member = frame.member ?? '<fn>';
    final List<String> members = member.split('.');
    if (members.length > 1) {
      element['method'] = members.sublist(1).join('.');
      element['class'] = members.first;
    } else {
      element['method'] = member;
    }
    elements.add(element);
  }

  return elements;
}
