#import "FlutterUxcamPlugin.h"
#import <UXCam/UXCam.h>
@implementation FlutterUxcamPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_uxcam"
                                     binaryMessenger:[registrar messenger]];
    FlutterUxcamPlugin* instance = [[FlutterUxcamPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startWithKey" isEqualToString:call.method]) {
        NSString* apiKey = call.arguments[@"key"];
        [UXCam startWithKey:apiKey];
    } else if ([@"startNewSession" isEqualToString:call.method]) {
        [UXCam startNewSession];
    } else if ([@"stopSessionAndUploadData" isEqualToString:call.method]) {
        [UXCam stopSessionAndUploadData];
    } else if ([@"allowShortBreakForAnotherApp" isEqualToString:call.method]) {
        BOOL continueSession = call.arguments[@"key"];
        [UXCam allowShortBreakForAnotherApp:continueSession];
    } else if ([@"occludeSensitiveScreen" isEqualToString:call.method]) {
        BOOL value = call.arguments[@"key"];
        [UXCam occludeSensitiveScreen:value];
    } else if ([@"occludeSensitiveScreenWithoutGesture" isEqualToString:call.method]) {
        BOOL value = call.arguments[@"key"];
        BOOL withoutGesture = call.arguments[@"withoutGesture"];
        [UXCam occludeSensitiveScreen:value hideGestures:withoutGesture];
    } else if ([@"occludeAllTextFields" isEqualToString:call.method]) {
        BOOL occludeAllTextField = call.arguments[@"key"];
        [UXCam occludeAllTextFields:occludeAllTextField];
    } else if ([@"occludeAllTextView" isEqualToString:call.method]) {
        NSLog(@"UXCam: Use occludeAllTextFields instead.");
    } else if ([@"tagScreenName" isEqualToString:call.method]) {
        NSString* eventName = call.arguments[@"key"];
        [UXCam tagScreenName:eventName];
    } else if ([@"setAutomaticScreenNameTagging" isEqualToString:call.method]) {
        BOOL enable = call.arguments[@"key"];
        [UXCam setAutomaticScreenNameTagging:enable];
    } else if ([@"setMultiSessionRecord" isEqualToString:call.method]) {
        BOOL enable = call.arguments[@"key"];
        [UXCam setMultiSessionRecord:enable];
    } else if ([@"getMultiSessionRecord" isEqualToString:call.method]) {
        BOOL status =  [UXCam getMultiSessionRecord];
        result(@(status));
    } else if ([@"setUserIdentity" isEqualToString:call.method]) {
        NSString* userIdentity = call.arguments[@"key"];
        [UXCam setUserIdentity:userIdentity];
    } else if ([@"setUserProperty" isEqualToString:call.method]) {
        NSString* userProperty = call.arguments[@"key"];
        NSString* value = call.arguments[@"value"];
        [UXCam setUserProperty:userProperty value:value];
    } else if ([@"logEvent" isEqualToString:call.method]) {
        NSString* eventName = call.arguments[@"key"];
        if (eventName.length>0){
            [UXCam logEvent:eventName];
        }
    } else if ([@"logEventWithProperties" isEqualToString:call.method]) {
        NSString* tag = call.arguments[@"eventName"];
        NSDictionary* properties = call.arguments[@"properties"];
        if (tag.length>0 && [properties isKindOfClass:NSDictionary.class]){
            [UXCam logEvent:tag withProperties:properties];
        }
    } else if ([@"isRecording" isEqualToString:call.method]) {
        BOOL isRecording = [UXCam isRecording];
        result(@(isRecording));
    } else if ([@"pauseScreenRecording" isEqualToString:call.method]) {
        [UXCam pauseScreenRecording];
    } else if ([@"resumeScreenRecording" isEqualToString:call.method]) {
        [UXCam resumeScreenRecording];
    } else if ([@"optInOverall" isEqualToString:call.method]) {
        [UXCam optInOverall];
    } else if ([@"optOutOverall" isEqualToString:call.method]) {
        [UXCam optOutOverall];
    } else if ([@"optInOverallStatus"isEqualToString:call.method]) {
        result(@( [UXCam optInOverallStatus]));
    } else if ([@"optIntoVideoRecording" isEqualToString:call.method]) {
        [UXCam optIntoSchematicRecordings];
    } else if ([@"optOutOfVideoRecording" isEqualToString:call.method]) {
        [UXCam optOutOfSchematicRecordings];
    } else if ([@"optInVideoRecordingStatus"isEqualToString:call.method]) {
        result(@( [UXCam optInSchematicRecordingStatus]));
    } else if ([@"optIntoSchematicRecordings" isEqualToString:call.method]) {
        [UXCam optIntoSchematicRecordings];
    } else if ([@"optOutOfSchematicRecordings" isEqualToString:call.method]) {
        [UXCam optOutOfSchematicRecordings];
    } else if ([@"optInSchematicRecordingStatus"isEqualToString:call.method]) {
        result(@( [UXCam optInSchematicRecordingStatus]));
    } else if ([@"cancelCurrentSession"isEqualToString:call.method]) {
        [UXCam cancelCurrentSession];
    } else if ([@"deletePendingUploads"isEqualToString:call.method]) {
        [UXCam deletePendingUploads];
    } else if ([@"pendingUploads"isEqualToString:call.method]) {
        result(@( [UXCam pendingUploads]));
    } else if ([@"stopApplicationAndUploadData"isEqualToString:call.method]) {
        [UXCam stopSessionAndUploadData];
    } else if ([@"tagScreenName"isEqualToString:call.method]) {
        NSString* screenName = call.arguments;
        [UXCam tagScreenName:screenName];
    } else if ([@"urlForCurrentUser"isEqualToString:call.method]) {
        NSString* url = [UXCam urlForCurrentUser];
        
        result(@[url]);
    } else if ([@"urlForCurrentSession"isEqualToString:call.method]) {
        NSString* url = [UXCam urlForCurrentSession];
        result(@[url]);
    }else if ([@"addVerificationListener"isEqualToString:call.method]) {
        NSLog(@"UXCam: addVerificationListener is not supported by UXCam iOS.");
    }else if ([@"addScreenNameToIgnore" isEqualToString:call.method]) {
        NSString* eventName = call.arguments[@"key"];
        [UXCam addScreenNameToIgnore:eventName];
    } else if ([@"removeScreenNameToIgnore" isEqualToString:call.method]) {
        NSString* eventName = call.arguments[@"key"];
       [UXCam removeScreenNameToIgnore:eventName];
    } else if ([@"removeAllScreenNamesToIgnore" isEqualToString:call.method]) {
       NSString* eventName = call.arguments[@"key"];
       [UXCam removeAllScreenNamesToIgnore];
    } else {
        result(FlutterMethodNotImplemented);
    }
}
@end
