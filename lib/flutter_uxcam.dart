import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class FlutterUxcam {
  static const MethodChannel _channel = const MethodChannel('flutter_uxcam');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> startWithKey(String key) async {
    bool status = await _channel.invokeMethod('startWithKey', {"key": key});
    return status;
  }

  static Future<void> startNewSession() async {
    await _channel.invokeMethod('startNewSession');
  }

  static Future<void> stopSessionAndUploadData() async {
    await _channel.invokeMethod('stopSessionAndUploadData');
  }

  static Future<void> occludeSensitiveScreen(bool hideScreen) async {
    await _channel.invokeMethod('occludeSensitiveScreen', {"key": hideScreen});
  }

  static Future<void> occludeSensitiveScreenWithoutGesture(
      bool hideScreen) async {
    await _channel.invokeMethod('occludeSensitiveScreenWithoutGesture',
        {"key": hideScreen, "withoutGesture": true});
  }

  static Future<void> occludeAllTextView(bool value) async {
    await _channel.invokeMethod('occludeAllTextView', {"key": value});
  }

  static Future<void> occludeAllTextFields(bool value) async {
    await _channel.invokeMethod('occludeAllTextFields', {"key": value});
  }

  static Future<void> tagScreenName(String screenName) async {
    await _channel.invokeMethod('tagScreenName', {"key": screenName});
  }

  static Future<void> setUserIdentity(String userIdentity) async {
    await _channel.invokeMethod('setUserIdentity', {"key": userIdentity});
  }

  static Future<void> setUserProperty(String key, String value) async {
    await _channel
        .invokeMethod('setUserProperty', {"key": key, "value": value});
  }

  static Future<void> setSessionProperty(String key, String value) async {
    await _channel
        .invokeMethod('setSessionProperty', {"key": key, "value": value});
  }

  static Future<void> logEvent(String logEvent) async {
    await _channel.invokeMethod('logEvent', {"key": logEvent});
  }

  static Future<void> logEventWithProperties(
      String eventName, Map<String, dynamic> properties) async {
    await _channel.invokeMethod('logEventWithProperties',
        {"eventName": eventName, "properties": properties});
  }

  static Future<bool> isRecording() async {
    bool starter = await _channel.invokeMethod('isRecording');
    return starter;
  }

  static Future<void> pauseScreenRecording() async {
    await _channel.invokeMethod('pauseScreenRecording');
  }

  static Future<void> resumeScreenRecording() async {
    await _channel.invokeMethod('resumeScreenRecording');
  }

  static Future<void> optInOverall() async {
    await _channel.invokeMethod('optInOverall');
  }

  static Future<void> optOutOverall() async {
    await _channel.invokeMethod('optOutOverall');
  }

  static Future<bool> optInOverallStatus() async {
    final bool optStatus = await _channel.invokeMethod('optInOverallStatus');
    return optStatus;
  }

  static Future<void> optIntoVideoRecording() async {
    await _channel.invokeMethod('optIntoVideoRecording');
  }

  static Future<void> optOutOfVideoRecording() async {
    await _channel.invokeMethod('optOutOfVideoRecording');
  }

  static Future<bool> optInVideoRecordingStatus() async {
    final bool optStatus =
        await _channel.invokeMethod('optInVideoRecordingStatus');
    return optStatus;
  }

  static Future<void> optIntoSchematicRecordings() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('optIntoSchematicRecordings');
    }
  }

  static Future<void> optOutOfSchematicRecordings() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('optOutOfSchematicRecordings');
    }
  }

  static Future<bool> optInSchematicRecordingStatus() async {
    if (Platform.isIOS) {
      final bool optStatus =
          await _channel.invokeMethod('optInSchematicRecordingStatus');
      return optStatus;
    }
    return false;
  }

  static Future<void> cancelCurrentSession() async {
    await _channel.invokeMethod('cancelCurrentSession');
  }

  static Future<void> allowShortBreakForAnotherApp(bool continueSession) async {
    await _channel
        .invokeMethod('allowShortBreakForAnotherApp', {"key": continueSession});
  }

  static Future<void> setMultiSessionRecord(bool multiSessionRecord) async {
    await _channel
        .invokeMethod('setMultiSessionRecord', {"key": multiSessionRecord});
  }

  static Future<bool> getMultiSessionRecord() async {
    bool starter = await _channel.invokeMethod('getMultiSessionRecord');
    return starter;
  }

  static Future<void> setAutomaticScreenNameTagging(bool enable) async {
    await _channel
        .invokeMethod('setAutomaticScreenNameTagging', {"key": enable});
  }

  static Future<void> resumeShortBreakForAnotherApp() async {
    await _channel.invokeMethod('resumeShortBreakForAnotherApp');
  }

  static Future<void> deletePendingUploads() async {
    await _channel.invokeMethod('deletePendingUploads');
  }

  static Future<int> pendingUploads() async {
    int count = await _channel.invokeMethod('pendingUploads');
    return count;
  }

  static Future<void> uploadPendingSession() async {
    await _channel.invokeMethod('uploadPendingSession');
  }

  static Future<void> stopApplicationAndUploadData() async {
    await _channel.invokeMethod('stopApplicationAndUploadData');
  }

  static Future<String> urlForCurrentUser() async {
    String url = await _channel.invokeMethod('urlForCurrentUser');
    return url;
  }

  static Future<String> urlForCurrentSession() async {
    String url = await _channel.invokeMethod('urlForCurrentSession');
    return url;
  }

  static Future<void> addScreenNameToIgnore(String screenName) async {
    await _channel.invokeMethod('addScreenNameToIgnore', {"key": screenName});
  }

  static Future<void> removeScreenNameToIgnore(String screenName) async {
    await _channel
        .invokeMethod('removeScreenNameToIgnore', {"key": screenName});
  }

  static Future<void> removeAllScreenNamesToIgnore(String screenName) async {
    await _channel.invokeMethod('removeAllScreenNamesToIgnore');
  }

  static Future<void> setPushNotificationToken(String token) async {
    await _channel.invokeMethod('setPushNotificationToken', {"key": token});
  }

  static Future<void> reportBugEvent(String eventName,
      [Map<String, dynamic> properties]) async {
    await _channel.invokeMethod(
        'reportBugEvent', {"eventName": eventName, "properties": properties});
  }
}
