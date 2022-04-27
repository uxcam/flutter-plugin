## Changelog
Version         | Changes
----------      | ----------
2.1.0           | iOS SDK updated to v 3.4.1 & Android SDK updated to v3.4.0
2.0.1			| Added plugin support for the Android v2 embedding
				| Android SDK 3.3.6, iOS SDK 3.3.6
2.0.0			| Added support for null-safety, which means a new minimum SDK environment of >=2.12.0
				| Added type specifiers for _channel.invokeMethod calls in the Dart code
				| Fixed a duplicate result on Android `optInOverallStatus` - thanks The Boston Consulting Group Pty Ltd
				| iOS SDK 3.3.4 & Android SDK 3.3.5
				| For iOS the minimum OS required is now iOS 10.0
1.3.2           | iOS SDK updated to v3.3.3, integration issue related to flutter driver solved, void function await deadlock fixed
1.3.1           | iOS SDK update to v 3.3.1 & Android SDK updated to v3.3.5
1.3.0           | iOS version updated to 3.3.0, android version updated to 3.3.4, setPushNotificationToken and reportBugEvent API added
1.2.1           | Dart env updated to use 2.2.0 stable, iOS SDK updated to 3.2.5, startWithKey changed to return session status, user and session URL return type error fixed
1.2.0           | Android SDK updated to v3.3.1 which solves Android screen video bug. iOS SDK updated to 3.2.4
1.1.2-beta.3    | Android SDK updated to 3.3.0-beta.1 which fixes issue with recording embedded Flutter view on release build. iOS SDK updated to 3.2.4
1.1.2-beta.2    | Dart hashmap to Java JSONObject conversion code compile time issue fixed  
1.1.2-beta.1    | IOS boolean conversion issue fixed for dart -> Obj C
1.1.1           | Android SDK updated to 3.2.0, iOS to 3.1.15
1.1.0-beta.6	| Android SDK updated to 3.1.13-beta.7 which solves issue with screen video recording on release build of the app.
1.1.0-beta.5	| Missing frame on Android screen recording bug fixed.
1.1.0-beta.4	| optIntoSchematicRecordings APIs added as optIntoVideoRecording APIs were not present on iOS SDK.
1.1.0-beta.3	| Screen recording issue on latest Flutter SDK version 1.12.13 fixed
1.1.0-beta.2	| Ignored unwanted build files that were included in previous package
1.1.0-beta.1	| Native Android SDK updated to 3.1.13-beta.1 which supports screen recording on Android.
1.0.0	        | This is the first version of UXCam package for Flutter.
