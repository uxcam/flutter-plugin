#import "FlutterUxcamPlugin.h"
#import <UXCam/UXCam.h>
@implementation FlutterUxcamPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_uxcam"
                                     binaryMessenger:[registrar messenger]];
	
    FlutterUxcamPlugin* instance = [[FlutterUxcamPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result
{
    if ([@"getPlatformVersion" isEqualToString:call.method])
	{
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    }
	else if ([@"startWithKey" isEqualToString:call.method])
	{
		[UXCam pluginType:@"flutter" version:@"1.3.2"];
        NSString* apiKey = call.arguments[@"key"];
        [UXCam startWithKey:apiKey completionBlock:^(BOOL started) {
            result(@(started));
        }];
    }
	else if ([@"startNewSession" isEqualToString:call.method])
	{
        [UXCam startNewSession];
        result(nil);
    }
	else if ([@"stopSessionAndUploadData" isEqualToString:call.method])
	{
        [UXCam stopSessionAndUploadData];
        result(nil);
    }
	else if ([@"allowShortBreakForAnotherApp" isEqualToString:call.method])
	{
        BOOL continueSession = call.arguments[@"key"];
        [UXCam allowShortBreakForAnotherApp:continueSession];
        result(nil);
    } else if ([@"occludeSensitiveScreen" isEqualToString:call.method]) {
        NSNumber *value = call.arguments[@"key"];
        [UXCam occludeSensitiveScreen:[value boolValue]];
        result(nil);
    } else if ([@"occludeSensitiveScreenWithoutGesture" isEqualToString:call.method]) {
        NSNumber *value = call.arguments[@"key"];
        NSNumber *withoutGesture = call.arguments[@"withoutGesture"];
        [UXCam occludeSensitiveScreen:[value boolValue] hideGestures:[withoutGesture boolValue]];
        result(nil);
    } else if ([@"occludeAllTextFields" isEqualToString:call.method]) {
        NSNumber *occludeAllTextField = call.arguments[@"key"];
        [UXCam occludeAllTextFields:[occludeAllTextField boolValue]];
        result(nil);
    } else if ([@"occludeAllTextView" isEqualToString:call.method]) {
        NSLog(@"UXCam: Use occludeAllTextFields instead.");
        result(nil);
    }
	else if ([@"tagScreenName" isEqualToString:call.method])
	{
        NSString* eventName = call.arguments[@"key"];
        [UXCam tagScreenName:eventName];
        result(nil);
    } else if ([@"setAutomaticScreenNameTagging" isEqualToString:call.method]) {
        NSNumber *enable = call.arguments[@"key"];
        [UXCam setAutomaticScreenNameTagging:[enable boolValue]];
        result(nil);
    } else if ([@"setMultiSessionRecord" isEqualToString:call.method]) {
        NSNumber *enable = call.arguments[@"key"];
        [UXCam setMultiSessionRecord:[enable boolValue]];
        result(nil);
    } else if ([@"getMultiSessionRecord" isEqualToString:call.method]) {
        BOOL status =  [UXCam getMultiSessionRecord];
        result(@(status));
    }
	else if ([@"setUserIdentity" isEqualToString:call.method])
	{
        NSString* userIdentity = call.arguments[@"key"];
        [UXCam setUserIdentity:userIdentity];
        result(nil);
    }
	else if ([@"setUserProperty" isEqualToString:call.method])
	{
        NSString* userProperty = call.arguments[@"key"];
        NSString* value = call.arguments[@"value"];
        [UXCam setUserProperty:userProperty value:value];
        result(nil);
    }
	else if ([@"logEvent" isEqualToString:call.method])
	{
        NSString* eventName = call.arguments[@"key"];
        if (eventName.length>0)
		{
            [UXCam logEvent:eventName];
        }
        result(nil);
    }
	else if ([@"logEventWithProperties" isEqualToString:call.method])
	{
        NSString* tag = call.arguments[@"eventName"];
        NSDictionary* properties = call.arguments[@"properties"];
        if (tag.length>0 && [properties isKindOfClass:NSDictionary.class])
		{
            [UXCam logEvent:tag withProperties:properties];
        }
        result(nil);
    }
	else if ([@"isRecording" isEqualToString:call.method])
	{
        BOOL isRecording = [UXCam isRecording];
        result(@(isRecording));
    }
	else if ([@"pauseScreenRecording" isEqualToString:call.method])
	{
        [UXCam pauseScreenRecording];
        result(nil);
    }
	else if ([@"resumeScreenRecording" isEqualToString:call.method])
	{
        [UXCam resumeScreenRecording];
        result(nil);
    }
	else if ([@"optInOverall" isEqualToString:call.method])
	{
        [UXCam optInOverall];
        result(nil);
    }
	else if ([@"optOutOverall" isEqualToString:call.method])
	{
        [UXCam optOutOverall];
        result(nil);
    }
	else if ([@"optInOverallStatus"isEqualToString:call.method])
	{
        result(@( [UXCam optInOverallStatus]));
    }
	else if ([@"optIntoVideoRecording" isEqualToString:call.method])
	{
        [UXCam optIntoSchematicRecordings];
        result(nil);
    }
	else if ([@"optOutOfVideoRecording" isEqualToString:call.method])
	{
        [UXCam optOutOfSchematicRecordings];
        result(nil);
    }
	else if ([@"optInVideoRecordingStatus"isEqualToString:call.method])
	{
        result(@( [UXCam optInSchematicRecordingStatus]));
    }
	else if ([@"optIntoSchematicRecordings" isEqualToString:call.method])
	{
        [UXCam optIntoSchematicRecordings];
        result(nil);
    }
	else if ([@"optOutOfSchematicRecordings" isEqualToString:call.method])
	{
        [UXCam optOutOfSchematicRecordings];
        result(nil);
    }
	else if ([@"optInSchematicRecordingStatus"isEqualToString:call.method])
	{
        result(@( [UXCam optInSchematicRecordingStatus]));
    }
	else if ([@"cancelCurrentSession"isEqualToString:call.method])
	{
        [UXCam cancelCurrentSession];
        result(nil);
    }
	else if ([@"deletePendingUploads"isEqualToString:call.method])
	{
        [UXCam deletePendingUploads];
        result(nil);
    }
	else if ([@"pendingUploads"isEqualToString:call.method])
	{
        result(@( [UXCam pendingUploads]));
    }
    else if ([@"uploadPendingSession"isEqualToString:call.method])
	{
        [UXCam uploadingPendingSessions:nil];
        result(nil);
    }
	else if ([@"stopApplicationAndUploadData"isEqualToString:call.method])
	{
        [UXCam stopSessionAndUploadData];
        result(nil);
    }
	else if ([@"tagScreenName"isEqualToString:call.method])
	{
        NSString* screenName = call.arguments;
        [UXCam tagScreenName:screenName];
        result(nil);
    }
	else if ([@"urlForCurrentUser"isEqualToString:call.method])
	{
        NSString* url = [UXCam urlForCurrentUser];
        result(url);
    }
	else if ([@"urlForCurrentSession"isEqualToString:call.method])
	{
        NSString* url = [UXCam urlForCurrentSession];
        result(url);
    }
	else if ([@"addVerificationListener"isEqualToString:call.method])
	{
        NSLog(@"UXCam: addVerificationListener is not supported by UXCam iOS.");
        result(nil);
    }
	else if ([@"addScreenNameToIgnore" isEqualToString:call.method])
	{
        NSString* eventName = call.arguments[@"key"];
        [UXCam addScreenNameToIgnore:eventName];
        result(nil);
    }
	else if ([@"removeScreenNameToIgnore" isEqualToString:call.method])
	{
        NSString* eventName = call.arguments[@"key"];
       [UXCam removeScreenNameToIgnore:eventName];
       result(nil);
    }
	else if ([@"removeAllScreenNamesToIgnore" isEqualToString:call.method])
	{
       [UXCam removeAllScreenNamesToIgnore];
       result(nil);
    }
    else if ([@"setPushNotificationToken" isEqualToString:call.method])
	{
        NSString* token = call.arguments[@"key"];
        [UXCam setPushNotificationToken:token];
        result(nil);
    }
    else if ([@"reportBugEvent" isEqualToString:call.method])
	{
        NSString* eventName = call.arguments[@"eventName"];
        NSDictionary* properties = call.arguments[@"properties"];
        if (eventName.length>0 && [properties isKindOfClass:NSDictionary.class])
		{
            [UXCam reportBugEvent:eventName properties:properties];
        }else
        {
            [UXCam reportBugEvent:eventName properties:nil];
        }
        result(nil);
    }
	else
	{
        result(FlutterMethodNotImplemented);
    }
}
@end
