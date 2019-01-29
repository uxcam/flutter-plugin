package com.uxcam.flutteruxcam;

import android.app.Activity;
import android.util.Log;

import org.json.JSONObject;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import com.uxcam.UXCam;
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
            UXCam.pluginType("flutter", "1.0.0");
//            Log.d("should start uxcam ", " yes yes yes "+key);

        }else if ("startNewSession".equals(call.method)) {
            UXCam.startNewSession();
        } else if ("stopSessionAndUploadData".equals(call.method)) {
            UXCam.stopSessionAndUploadData();
        } else if ("occludeSensitiveScreen".equals(call.method)) {
            boolean occludeSensitiveScreen = call.argument("key");
            Log.d(TAG, "occludeSenstiveScreen: "+occludeSensitiveScreen);
            UXCam.occludeSensitiveScreen(occludeSensitiveScreen);
        }else if ("occludeSensitiveScreenWithoutGesture".equals(call.method)) {
            boolean occludeSensitiveScreen = call.argument("key");
            boolean withoutGesture = call.argument("withoutGesture");
//            Log.d(TAG, "occludeSensitiveScreenWithoutGesture: "+occludeSensitiveScreen);
            UXCam.occludeSensitiveScreen(occludeSensitiveScreen,withoutGesture);
        } else if ("setMultiSessionRecord".equals(call.method)) {
            boolean multiSessionRecord = call.argument("key");
//            Log.d(TAG, "setMultiSessionRecord: "+multiSessionRecord);
            UXCam.setMultiSessionRecord(multiSessionRecord);
        } else if ("getMultiSessionRecord".equals(call.method)) {

            result.success( UXCam.getMultiSessionRecord());
        }
        else if ("occludeAllTextView".equals(call.method)) {
            boolean occludeAllTextField = call.argument("key");
            UXCam.occludeAllTextFields(occludeAllTextField);
        } else if ("tagScreenName".equals(call.method)) {
            String eventName = call.argument("key");
            UXCam.tagScreenName(eventName);
        } else if ("setAutomaticScreenNameTagging".equals(call.method)) {
//            Log.d("UXCamPlugin", "action " + call.method + " is not supported by UXCam Android");
        } else if ("setUserIdentity".equals(call.method)) {

            String userIdentity = call.argument("key");
            UXCam.setUserIdentity(userIdentity);
        } else if ("setUserProperty".equals(call.method)) {
            String key = call.argument("key");
            String value = call.argument("value");
            UXCam.setUserProperty(key, value);
        } else if ("setSessionProperty".equals(call.method)) {
            String key = call.argument("key");
            String value = call.argument("value");
            UXCam.setSessionProperty(key, value);
        } else if ("logEvent".equals(call.method)) {
            String eventName = call.argument("key");
            if (eventName == null || eventName.length() == 0) {
                throw new IllegalArgumentException("missing event Name");
            }
            UXCam.logEvent(eventName);
        } else if ("logEventWithProperties".equals(call.method)) {
            String eventName = call.argument("eventName");
            JSONObject params = call.argument("properties");

            if (eventName == null || eventName.length() == 0) {
                throw new IllegalArgumentException("missing event Name");
            }
            if (params == null || params.length() == 0) {
                UXCam.logEvent(eventName);
            } else {
                UXCam.logEvent(eventName, params);
            }
        } else if ("isRecording".equals(call.method)) {
            result.success( UXCam.isRecording());
        } else if ("pauseScreenRecording".equals(call.method)) {
            UXCam.pauseScreenRecording();
        } else if ("resumeScreenRecording".equals(call.method)) {
            UXCam.resumeScreenRecording();
        } else if ("optIn".equals(call.method)) {
            UXCam.optIn();
        } else if ("optOut".equals(call.method)) {
            UXCam.optOut();
        } else if ("optStatus".equals(call.method)) {
            result.success(UXCam.optInStatus());
        } else if ("cancelCurrentSession".equals(call.method)) {
            UXCam.cancelCurrentSession();
        } else if ("allowShortBreakForAnotherApp".equals(call.method)) {
            UXCam.allowShortBreakForAnotherApp();
        } else if ("resumeShortBreakForAnotherApp".equals(call.method)) {
            UXCam.resumeShortBreakForAnotherApp();
        } else if ("deletePendingUploads".equals(call.method)) {
            UXCam.deletePendingUploads();
        } else if ("pendingSessionCount".equals(call.method)) {
            result.success(UXCam.pendingSessionCount());
        } else if ("stopApplicationAndUploadData".equals(call.method)) {
            UXCam.stopSessionAndUploadData();
        } else if ("tagScreenName".equals(call.method)) {
            String screenName = call.arguments();
            if (screenName == null || screenName.length() == 0) {
                throw new IllegalArgumentException("missing screen Name");
            }
            UXCam.tagScreenName(screenName);
        }
        else if ("addVerificationListener".equals(call.method)) {
            String url = UXCam.urlForCurrentUser();
            if (url == null || url.contains("null")) {
                addListener(result);
            }
            result.success(url);
        } else if ("urlForCurrentUser".equals(call.method)) {
            String url = UXCam.urlForCurrentUser();
            System.out.println("urlForCurrentUser "+url);
            result.success(url);
        } else if ("urlForCurrentSession".equals(call.method)) {
            String url = UXCam.urlForCurrentSession();
            result.success(url);
        } /*else {
            callbackContext.error("This API call is not supported by UXCam Android, API called: " + call.method);
            return false;
        }*/

        else {
            result.notImplemented();
        }
    }
    private void addListener(final Result callback) {
        com.uxcam.UXCam.addVerificationListener(new com.uxcam.OnVerificationListener() {
            @Override
            public void onVerificationSuccess() {
                callback.success(com.uxcam.UXCam.urlForCurrentUser());
            }

            @Override
            public void onVerificationFailed(String errorMessage) {
                callback.error(errorMessage,"","");
            }
        });
    }
}
