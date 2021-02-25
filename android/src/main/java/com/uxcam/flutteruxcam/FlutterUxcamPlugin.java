package com.uxcam.flutteruxcam;

import android.app.Activity;
import android.util.Log;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import com.uxcam.UXCam;
import java.util.Map;
/**
 * FlutterUxcamPlugin
 */
public class FlutterUxcamPlugin implements MethodCallHandler {
    public static final String TAG = "FlutterUXCam";
    /**
     * Plugin registration.
     */
    private final Activity activity;

    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_uxcam");
        channel.setMethodCallHandler(new FlutterUxcamPlugin(registrar.activity()));
    }

    private FlutterUxcamPlugin(Activity activity) {
        this.activity = activity;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("getPlatformVersion")) {
            result.success("Android " + android.os.Build.VERSION.RELEASE);
        } else if (call.method.equals("startWithKey")) {
            String key = call.argument("key");
            UXCam.startApplicationWithKeyForCordova(activity, key);
            addListener(result);
            UXCam.pluginType("flutter", "1.3.2");
        } else if ("startNewSession".equals(call.method)) {
            UXCam.startNewSession();
            result.success(null);
        } else if ("stopSessionAndUploadData".equals(call.method)) {
            UXCam.stopSessionAndUploadData();
            result.success(null);
        } else if ("occludeSensitiveScreen".equals(call.method)) {
            boolean occludeSensitiveScreen = call.argument("key");
            UXCam.occludeSensitiveScreen(occludeSensitiveScreen);
            result.success(null);
        }else if ("occludeSensitiveScreenWithoutGesture".equals(call.method)) {
            boolean occludeSensitiveScreen = call.argument("key");
            boolean withoutGesture = call.argument("withoutGesture");
            UXCam.occludeSensitiveScreen(occludeSensitiveScreen,withoutGesture);
            result.success(null);
        } else if ("setMultiSessionRecord".equals(call.method)) {
            boolean multiSessionRecord = call.argument("key");
            UXCam.setMultiSessionRecord(multiSessionRecord);
            result.success(null);
        } else if ("getMultiSessionRecord".equals(call.method)) {
            result.success( UXCam.getMultiSessionRecord());
        } else if ("occludeAllTextView".equals(call.method)) {
            boolean occludeAllTextField = call.argument("key");
            UXCam.occludeAllTextFields(occludeAllTextField);
            result.success(null);
        } else if ("tagScreenName".equals(call.method)) {
            String eventName = call.argument("key");
            UXCam.tagScreenName(eventName);
            result.success(null);
        } else if ("setAutomaticScreenNameTagging".equals(call.method)) {
            boolean enable = call.argument("key");
            UXCam.setAutomaticScreenNameTagging(enable);
            result.success(null);
        } else if ("setUserIdentity".equals(call.method)) {
            String userIdentity = call.argument("key");
            UXCam.setUserIdentity(userIdentity);
            result.success(null);
        } else if ("setUserProperty".equals(call.method)) {
            String key = call.argument("key");
            String value = call.argument("value");
            UXCam.setUserProperty(key, value);
            result.success(null);
        } else if ("setSessionProperty".equals(call.method)) {
            String key = call.argument("key");
            String value = call.argument("value");
            UXCam.setSessionProperty(key, value);
            result.success(null);
        } else if ("logEvent".equals(call.method)) {
            String eventName = call.argument("key");
            if (eventName == null || eventName.length() == 0) {
                throw new IllegalArgumentException("missing event Name");
            }
            UXCam.logEvent(eventName);
            result.success(null);
        } else if ("logEventWithProperties".equals(call.method)) {
            String eventName = call.argument("eventName");
            final Map<String, Object> map = call.argument("properties");
            if (eventName == null || eventName.length() == 0) {
                throw new IllegalArgumentException("missing event Name");
            }
            if (map == null || map.size() == 0) {
                UXCam.logEvent(eventName);
            } else {
                UXCam.logEvent(eventName, map);
            }
            result.success(null);
        } else if ("isRecording".equals(call.method)) {
            result.success( UXCam.isRecording());
        } else if ("pauseScreenRecording".equals(call.method)) {
            UXCam.pauseScreenRecording();
            result.success(null);
        } else if ("resumeScreenRecording".equals(call.method)) {
            UXCam.resumeScreenRecording();
            result.success(null);
        } else if ("optInOverall".equals(call.method)) {
            UXCam.optInOverall();
            result.success(null);
        } else if ("optOutOverall".equals(call.method)) {
            UXCam.optOutOverall();
            result.success(null);
        } else if ("optInOverallStatus".equals(call.method)) {
            result.success(UXCam.optInOverallStatus());
            result.success(null);
        } else if ("optIntoVideoRecording".equals(call.method)) {
            UXCam.optIntoVideoRecording();
            result.success(null);
        } else if ("optOutOfVideoRecording".equals(call.method)) {
            UXCam.optOutOfVideoRecording();
            result.success(null);
        } else if ("optInVideoRecordingStatus".equals(call.method)) {
            result.success(UXCam.optInVideoRecordingStatus());
        } else if ("cancelCurrentSession".equals(call.method)) {
            UXCam.cancelCurrentSession();
            result.success(null);
        } else if ("allowShortBreakForAnotherApp".equals(call.method)) {
            boolean enable = call.argument("key");
            UXCam.allowShortBreakForAnotherApp(enable);
            result.success(null);
        } else if ("resumeShortBreakForAnotherApp".equals(call.method)) {
            UXCam.resumeShortBreakForAnotherApp();
            result.success(null);
        } else if ("deletePendingUploads".equals(call.method)) {
            UXCam.deletePendingUploads();
            result.success(null);
        } else if ("pendingUploads".equals(call.method)) {
            result.success(UXCam.pendingUploads());
        } else if ("uploadPendingSession".equals(call.method)) {
            result.success(null);
        }
        else if ("stopApplicationAndUploadData".equals(call.method)) {
            UXCam.stopSessionAndUploadData();
            result.success(null);
        } else if ("tagScreenName".equals(call.method)) {
            String screenName = call.arguments();
            if (screenName == null || screenName.length() == 0) {
                throw new IllegalArgumentException("missing screen Name");
            }
            UXCam.tagScreenName(screenName);
            result.success(null);
        }
        else if ("urlForCurrentUser".equals(call.method)) {
            String url = UXCam.urlForCurrentUser();
            result.success(url);
        } else if ("urlForCurrentSession".equals(call.method)) {
            String url = UXCam.urlForCurrentSession();
            result.success(url);
        } else if ("addScreenNameToIgnore".equals(call.method)) {
            String screenName = call.argument("key");
            UXCam.addScreenNameToIgnore(screenName);
            result.success(null);
        } else if ("removeScreenNameToIgnore".equals(call.method)) {
            String screenName = call.argument("key");
            UXCam.removeScreenNameToIgnore(screenName);
            result.success(null);
        } else if ("removeAllScreenNamesToIgnore".equals(call.method)) {
            UXCam.removeAllScreenNamesToIgnore();
            result.success(null);
        } else if ("setPushNotificationToken".equals(call.method)) {
            String token = call.argument("key");
            UXCam.setPushNotificationToken(token);
            result.success(null);
        } else if ("reportBugEvent".equals(call.method)) {
            String eventName = call.argument("eventName");
            final Map<String, Object> map = call.argument("properties");
            if (eventName == null || eventName.length() == 0) {
                throw new IllegalArgumentException("missing event Name");
            }
            if (map == null || map.size() == 0) {
                UXCam.reportBugEvent(eventName);
            } else {
                UXCam.reportBugEvent(eventName, map);
            }
            result.success(null);
        } else {
            result.notImplemented();
        }
    }

    private void addListener(final Result callback) {
        com.uxcam.UXCam.addVerificationListener(new com.uxcam.OnVerificationListener() {
            @Override
            public void onVerificationSuccess() {
                callback.success(true);
            }

            @Override
            public void onVerificationFailed(String errorMessage) {
                callback.success(false);
            }
        });
    }
}
