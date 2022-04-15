import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_occlusion.dart';

class FlutterUxConfigKeys {
  static const userAppKey = "userAppKey";
  static const enableMultiSessionRecord = "enableMultiSessionRecord";
  static const enableCrashHandling = "enableCrashHandling";
  static const enableAutomaticScreenNameTagging = "enableAutomaticScreenNameTagging";
  static const enableNetworkLogging = "enableNetworkLogging";
  static const enableAdvancedGestureRecognition = "enableAdvancedGestureRecognition";
  static const occlusion = "occlusion";
  static const enableImprovedScreenCapture = "enableImprovedScreenCapture";
}


class FlutterUxConfig {
  String userAppKey;

  // If value is not specified for below variables, default values will be applied as per sdk
  bool? enableMultiSessionRecord;
  bool? enableCrashHandling;
  bool? enableAutomaticScreenNameTagging;
  bool? enableNetworkLogging;
  bool? enableAdvancedGestureRecognition;
  List<FlutterUXOcclusion>? occlusions;

  FlutterUxConfig({
    required this.userAppKey,
    this.enableMultiSessionRecord,
    this.enableCrashHandling,
    this.enableAutomaticScreenNameTagging,
    this.enableNetworkLogging,
    this.enableAdvancedGestureRecognition,
    this.occlusions
  });

  factory FlutterUxConfig.fromJson(Map<String, dynamic> json) {
      var userAppKey = json[FlutterUxConfigKeys.userAppKey];
      var config = FlutterUxConfig(userAppKey: userAppKey);
      config.enableMultiSessionRecord = json[FlutterUxConfigKeys.enableMultiSessionRecord];
      config.enableCrashHandling = json[FlutterUxConfigKeys.enableCrashHandling];
      config.enableAutomaticScreenNameTagging = json[FlutterUxConfigKeys.enableAutomaticScreenNameTagging];
      config.enableNetworkLogging = json[FlutterUxConfigKeys.enableNetworkLogging];
      config.enableAdvancedGestureRecognition = json[FlutterUxConfigKeys.enableAdvancedGestureRecognition];
      return config;
  }

  Map<String, dynamic> toJson() {
    return {
      FlutterUxConfigKeys.userAppKey: userAppKey,
      FlutterUxConfigKeys.enableMultiSessionRecord: enableMultiSessionRecord,
      FlutterUxConfigKeys.enableCrashHandling: enableCrashHandling,
      FlutterUxConfigKeys.enableAutomaticScreenNameTagging: enableAutomaticScreenNameTagging,
      FlutterUxConfigKeys.enableNetworkLogging: enableNetworkLogging,
      FlutterUxConfigKeys.enableAdvancedGestureRecognition: enableAdvancedGestureRecognition,
      FlutterUxConfigKeys.occlusion: occlusions?.map((occlusion) => occlusion.toJson()).toList()
    };
  }
}

class FlutterUxcam {
  static const MethodChannel _channel = const MethodChannel('flutter_uxcam');

  static Future<String> get platformVersion async {
    final String? version =
        await _channel.invokeMethod<String>('getPlatformVersion');
    return version!;
  }

  static Future<bool> startWithConfiguration(FlutterUxConfig config) async {
    final bool? status =
    await _channel.invokeMethod<bool>('startWithConfiguration', {"config": config.toJson()});
    return status!;
  }

  static Future<FlutterUxConfig> configurationForUXCam() async {
    final Map<String, dynamic>? json = await _channel.invokeMapMethod('configurationForUXCam');
    return FlutterUxConfig.fromJson(json!);
  }

  static Future<bool> updateConfiguration(FlutterUxConfig config) async {
    final bool? status =
    await _channel.invokeMethod<bool>('updateConfiguration', {"config": config.toJson()});
    return status!;
  }

  static Future<bool> startWithKey(String key) async {
    final bool? status =
        await _channel.invokeMethod<bool>('startWithKey', {"key": key});
    return status!;
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

  @Deprecated('Use `occludeAllTextFields`')
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
    final bool? starter = await _channel.invokeMethod<bool>('isRecording');
    return starter!;
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
    final bool? optStatus =
        await _channel.invokeMethod<bool>('optInOverallStatus');
    return optStatus!;
  }

  static Future<void> optIntoVideoRecording() async {
    await _channel.invokeMethod('optIntoVideoRecording');
  }

  static Future<void> optOutOfVideoRecording() async {
    await _channel.invokeMethod('optOutOfVideoRecording');
  }

  static Future<bool> optInVideoRecordingStatus() async {
    final bool? optStatus =
        await _channel.invokeMethod<bool>('optInVideoRecordingStatus');
    return optStatus!;
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
      final bool? optStatus =
          await _channel.invokeMethod<bool>('optInSchematicRecordingStatus');
      return optStatus!;
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
    final bool? value =
        await _channel.invokeMethod<bool>('getMultiSessionRecord');
    return value!;
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
    final int? count = await _channel.invokeMethod<int>('pendingUploads');
    return count!;
  }

  static Future<void> uploadPendingSession() async {
    await _channel.invokeMethod('uploadPendingSession');
  }

  @Deprecated("Please use stopSessionAndUploadData() instead")
  static Future<void> stopApplicationAndUploadData() async {
    await _channel.invokeMethod('stopApplicationAndUploadData');
  }

  static Future<String?> urlForCurrentUser() async {
    final String? url =
        await _channel.invokeMethod<String>('urlForCurrentUser');
    return url;
  }

  static Future<String?> urlForCurrentSession() async {
    final String? url =
        await _channel.invokeMethod<String>('urlForCurrentSession');
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
      [Map<String, dynamic>? properties]) async {
    await _channel.invokeMethod(
        'reportBugEvent', {"eventName": eventName, "properties": properties});
  }

  static Future<bool> applyOcclusion(FlutterUXOcclusion occlusion) async {
    final bool? status = await _channel.invokeMethod<bool>(
        'applyOcclusion',
        { "occlusion": occlusion.toJson()}
    );
    return status!;
  }

  static Future<bool> removeOcclusion(FlutterUXOcclusion occlusion) async {
    final bool? status = await _channel.invokeMethod<bool>(
        'removeOcclusion',
        { "occlusion": occlusion.toJson() }
    );
    return status!;
  }
}
