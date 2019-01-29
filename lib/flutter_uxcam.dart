import 'dart:async';
import 'package:flutter/services.dart';

class FlutterUxcam {
  static const MethodChannel _channel =
      const MethodChannel('flutter_uxcam');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  static void startWithKey(String key) async{
    await _channel. invokeMethod('startWithKey',{"key":key});
  }
  static Future<void> startNewSession() async{
    await _channel.invokeMethod('startNewSession');
  }
  static Future<void> stopSessionAndUploadData() async{
    await _channel.invokeMethod('stopSessionAndUploadData');
  }
  static Future<void> occludeSensitiveScreen(bool hideScreen) async{
    await _channel.invokeMethod('occludeSensitiveScreen',{"key":hideScreen});
  }
  static Future<void> occludeSensitiveScreenWithoutGesture(bool hideScreen) async{
    await _channel.invokeMethod('occludeSensitiveScreenWithoutGesture',{"key":hideScreen,"withoutGesture":true});
  }
  static Future<void> occludeAllTextView(bool value) async{
    await _channel.invokeMethod('occludeAllTextView',{"key":value});
  }
  static Future<void> occludeAllTextFields(bool value) async{
    await _channel.invokeMethod('occludeAllTextFields',{"key":value});
  }
  static Future<void> tagScreenName(String screenName) async{
    await _channel.invokeMethod('tagScreenName',{"key":screenName});
  }
  static Future<void> setUserIdentity(String userIdentity) async{
    await _channel.invokeMethod('setUserIdentity',{"key":userIdentity});
  }
  static Future<void> setUserProperty(String key,String value) async{
    await _channel.invokeMethod('setUserProperty',{"key":key,"value":value});
  }
  static Future<void> setSessionProperty(String key,String value) async{
    await _channel.invokeMethod('setSessionProperty',{"key":key,"value":value});
  }
  static Future<void> logEvent(String logEvent) async{
    await _channel.invokeMethod('logEvent',{"key":logEvent});
  }
  static Future<void> logEventWithProperties(String eventName,Object properties) async{
    await _channel.invokeMethod('logEventWithProperties',{"eventName":eventName,"properties":properties});
  }
  static Future<bool> isRecording() async{
     bool starter = await _channel.invokeMethod('isRecording');
    return starter;
  }
  static Future<bool> getMultiSessionRecord() async{
    bool starter = await _channel.invokeMethod('getMultiSessionRecord');
    return starter;
  }
  static Future<void> pauseScreenRecording() async{
    await _channel.invokeMethod('pauseScreenRecording');
  }
  static Future<void> resumeScreenRecording() async{
    await _channel.invokeMethod('resumeScreenRecording');
  }
  static Future<void> optIn() async{
    await _channel.invokeMethod('optIn');
  }
  static Future<void> optOut() async{
    await _channel.invokeMethod('optOut');
  }
  static Future<bool> optStatus() async{
   final bool optStatus= await _channel.invokeMethod('optStatus');
   return optStatus;
  }
  static Future<void> cancelCurrentSession() async{
    await _channel.invokeMethod('cancelCurrentSession');
  }
  static Future<void> allowShortBreakForAnotherApp(bool continueSession) async{
    await _channel.invokeMethod('allowShortBreakForAnotherApp',{"key":continueSession});
  }
  static Future<void> setMultiSessionRecord(bool multiSessionRecord) async{
    await _channel.invokeMethod('setMultiSessionRecord',{"key":multiSessionRecord});
  }
  static Future<void> setAutomaticScreenNameTagging(bool enable) async{
    await _channel.invokeMethod('setAutomaticScreenNameTagging',{"key":enable});
  }
  static Future<void> resumeShortBreakForAnotherApp() async{
    await _channel.invokeMethod('resumeShortBreakForAnotherApp');
  }
  static Future<void> deletePendingUploads() async{
    await _channel.invokeMethod('deletePendingUploads');
  }
  static Future<int> pendingSessionCount() async{
   int count =  await _channel.invokeMethod('pendingSessionCount');
   return count;
  }
  static Future<void> stopApplicationAndUploadData() async{
    await _channel.invokeMethod('stopApplicationAndUploadData');
  }
  static Future<String> urlForCurrentUser() async{
    String url = await _channel.invokeMethod('urlForCurrentUser');
    print("flutter_uxcam urlForCurrentUser "+url);
    return url;
  }
  static Future<String> urlForCurrentSession() async{
    String url = await _channel.invokeMethod('urlForCurrentSession');

    return url;
  }
  static Future<String> addVerificationListener() async{
    String url = await _channel.invokeMethod('addVerificationListener');
    return url;
  }
}
