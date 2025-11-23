import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/keys.dart';

/// Configuration Model for specifying flags to be sent to server
///
/// For values that are not set, sdk defaults will be added.
///
/// [userAppKey] is String. Required. Should be present to start SDK
///
/// [enableIntegrationLogging] is boolean and default set to false.
///
/// [enableMultiSessionRecord] is boolean
///
/// [enableCrashHandling] is boolean
///
/// [enableAutomaticScreenNameTagging] is boolean
///
/// * See: [Flutter Tagging Approach](https://developer.uxcam.com/docs/flutter-tagging-approach)
///
/// [enableAdvancedGestureRecognition] is boolean
///
/// [occlusions] is FlutterOcclusion Object for occlusion or blurring
class FlutterUxConfig {
  String userAppKey;

  bool? enableIntegrationLogging;
  bool? enableMultiSessionRecord;
  bool? enableCrashHandling;
  bool? enableAutomaticScreenNameTagging;
  bool? enableNetworkLogging;
  bool? enableAdvancedGestureRecognition;
  List<FlutterUXOcclusion>? occlusions;

  FlutterUxConfig({
    required this.userAppKey,
    this.enableIntegrationLogging,
    this.enableMultiSessionRecord,
    this.enableCrashHandling,
    this.enableAutomaticScreenNameTagging,
    this.enableNetworkLogging,
    this.enableAdvancedGestureRecognition,
    this.occlusions,
  });

  factory FlutterUxConfig.fromJson(Map<String, dynamic> json) {
    var userAppKey = json[FlutterUxConfigKeys.userAppKey];
    var config = FlutterUxConfig(userAppKey: userAppKey);
    config.enableIntegrationLogging =
        json[FlutterUxConfigKeys.enableIntegrationLogging];
    config.enableMultiSessionRecord =
        json[FlutterUxConfigKeys.enableMultiSessionRecord];
    config.enableCrashHandling = json[FlutterUxConfigKeys.enableCrashHandling];
    config.enableAutomaticScreenNameTagging =
        json[FlutterUxConfigKeys.enableAutomaticScreenNameTagging];
    config.enableNetworkLogging =
        json[FlutterUxConfigKeys.enableNetworkLogging];
    config.enableAdvancedGestureRecognition =
        json[FlutterUxConfigKeys.enableAdvancedGestureRecognition];
    return config;
  }

  Map<String, dynamic> toJson() {
    return {
      FlutterUxConfigKeys.userAppKey: userAppKey,
      FlutterUxConfigKeys.enableIntegrationLogging: enableIntegrationLogging,
      FlutterUxConfigKeys.enableMultiSessionRecord: enableMultiSessionRecord,
      FlutterUxConfigKeys.enableCrashHandling: enableCrashHandling,
      FlutterUxConfigKeys.enableAutomaticScreenNameTagging:
          enableAutomaticScreenNameTagging,
      FlutterUxConfigKeys.enableNetworkLogging: enableNetworkLogging,
      FlutterUxConfigKeys.enableAdvancedGestureRecognition:
          enableAdvancedGestureRecognition,
      FlutterUxConfigKeys.occlusion:
          occlusions?.map((occlusion) => occlusion.toJson()).toList()
    };
  }
}
