package com.uxcam.flutteruxcam;

import android.app.Activity;
import android.os.Build;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.common.BasicMessageChannel.MessageHandler;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.BasicMessageChannel.Reply;
// import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.StringCodec;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

import com.uxcam.UXCam;
import com.uxcam.screenshot.screenshotTaker.CrossPlatformDelegate;
import com.uxcam.screenshot.screenshotTaker.OcclusionRectRequestListener;
import com.uxcam.internal.FlutterFacade;
import com.uxcam.screenshot.model.UXCamBlur;
import com.uxcam.screenshot.model.UXCamOverlay;
import com.uxcam.screenshot.model.UXCamOcclusion;
import com.uxcam.screenshot.model.UXCamOccludeAllTextFields;
import com.uxcam.datamodel.UXConfig;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Objects;
import android.graphics.Rect;

import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;
import androidx.annotation.NonNull;
import java.util.TreeMap;

/**
 * FlutterUxcamPlugin
 */
public class FlutterUxcamPlugin implements MethodCallHandler, FlutterPlugin, ActivityAware {
    private static final String TYPE_VERSION = "2.5.7";
    public static final String TAG = "FlutterUXCam";
    public static final String USER_APP_KEY = "userAppKey";
    public static final String ENABLE_MUTLI_SESSION_RECORD = "enableMultiSessionRecord";
    public static final String ENABLE_CRASH_HANDLING = "enableCrashHandling";
    public static final String ENABLE_AUTOMATIC_SCREEN_NAME_TAGGING = "enableAutomaticScreenNameTagging";
    public static final String ENABLE_IMPROVED_SCREEN_CAPTURE = "enableImprovedScreenCapture";
    public static final String OCCLUSION = "occlusion";
    public static final String SCREENS = "screens";
    public static final String NAME = "name";
    public static final String TYPE = "type";
    public static final String EXCLUDE_MENTIONED_SCREENS = "excludeMentionedScreens";
    public static final String CONFIG = "config";
    public static final String BLUR_RADIUS = "radius";
    public static final String HIDE_GESTURES = "hideGestures";
    public static final String GAUSSIAN_BLUR = "gaussianBlur";
    public static final String STACK_BLUR = "stackBlur";
    public static final String BOX_BLUR = "boxBlur";
    public static final String BOKEH_BLUR = "bokehBlur";

    /**
     * Plugin registration.
     */
    private static Activity activity;

    private CrossPlatformDelegate delegate;

    private long bootTimeOffset;
    private TreeMap<Long, String> frameDataMap = new TreeMap<Long, String>();

    // public static void registerWith(Registrar registrar) {
    //     activity = registrar.activity();
    //     register(registrar.messenger());
    // }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
                final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_uxcam");
        final BasicMessageChannel<Object> occlusionRectsChannel = new BasicMessageChannel<>(
                binding.getBinaryMessenger(),
                "occlusion_rects_coordinates",
                StringCodec.INSTANCE);
        delegate = UXCam.getDelegate();
        delegate.setListener(new OcclusionRectRequestListener() {
            @Override
            public void processOcclusionRectsForCurrentFrame(long startTimeStamp,long stopTimeStamp) { 
                Long effectiveStartTimestamp = frameDataMap.lowerKey(startTimeStamp-10);
                if(effectiveStartTimestamp == null && frameDataMap.size() > 0) {
                    effectiveStartTimestamp = frameDataMap.firstKey();
                }
                Long effectiveEndTimestamp = frameDataMap.higherKey(stopTimeStamp+10);
                if(effectiveEndTimestamp == null && frameDataMap.size() > 0) {
                    effectiveEndTimestamp = frameDataMap.lastKey();
                }
                if(effectiveEndTimestamp != null && effectiveStartTimestamp!=null) {
                    ArrayList<Rect> result = combineRectDataIfSimilar(effectiveStartTimestamp, effectiveEndTimestamp);
                    frameDataMap.headMap(effectiveStartTimestamp, false).clear();
                    delegate.createScreenshotFromCollectedRects(result);
                } else {
                    delegate.createScreenshotFromCollectedRects(new ArrayList<Rect>());
                }

            }
        });
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }

    // public static void register(BinaryMessenger messenger) {
    //     final MethodChannel channel = new MethodChannel(messenger, "flutter_uxcam");
    //     final BasicMessageChannel<String> occlusionRectsChannel = new BasicMessageChannel<String>(
    //             messenger,
    //             "your_channel_name",
    //             StringCodec.INSTANCE);
    //     channel.setMethodCallHandler(new FlutterUxcamPlugin());
    //     occlusionRectsChannel.setMessageHandler(this);
    // }


    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("getPlatformVersion")) {
            result.success("Android " + Build.VERSION.RELEASE);
        } else if (call.method.equals("startWithKey")) {
            String key = call.argument("key");
            UXCam.startApplicationWithKeyForCordova(activity, key);
            addListener(result);
            UXCam.pluginType("flutter", TYPE_VERSION);
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
        } else if ("occludeSensitiveScreenWithoutGesture".equals(call.method)) {
            boolean occludeSensitiveScreen = call.argument("key");
            boolean withoutGesture = call.argument("withoutGesture");
            UXCam.occludeSensitiveScreen(occludeSensitiveScreen, withoutGesture);
            result.success(null);
        } else if (call.method.equals("occludeRectWithCoordinates")) {
            JSONArray data = new JSONArray();
            data.put(call.argument("x0"));
            data.put(call.argument("y0"));
            data.put(call.argument("x1"));
            data.put(call.argument("y1"));
            JSONArray coordinates = new JSONArray();
            coordinates.put(data);
            UXCam.flutterOccludeRectsOnNextFrame(coordinates);
            result.success(null);
        } else if ("setMultiSessionRecord".equals(call.method)) {
            boolean multiSessionRecord = call.argument("key");
            UXCam.setMultiSessionRecord(multiSessionRecord);
            result.success(null);
        } else if ("getMultiSessionRecord".equals(call.method)) {
            result.success(UXCam.getMultiSessionRecord());
        } else if ("occludeAllTextView".equals(call.method)) {
            boolean occludeAllTextField = call.argument("key");
            UXCam.occludeAllTextFields(occludeAllTextField);
            result.success(null);
        } else if ("occludeAllTextFields".equals(call.method)) {
            boolean occludeAllTextField = call.argument("key");
            UXCam.occludeAllTextFields(occludeAllTextField);
            result.success(null);
        } else if ("tagScreenName".equals(call.method)) {
            String eventName = call.argument("key");
            FlutterFacade.getInstance().tagScreenName(eventName);
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
            result.success(UXCam.isRecording());
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
        } else if ("allowShortBreakForAnotherAppWithDuration".equals(call.method)) {
            int duration = call.argument("duration");
            UXCam.allowShortBreakForAnotherApp(duration);
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
        } else if ("stopApplicationAndUploadData".equals(call.method)) {
            UXCam.stopSessionAndUploadData();
            result.success(null);
        } else if ("urlForCurrentUser".equals(call.method)) {
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
        } else if ("reportExceptionEvent".equals(call.method)) {
            final String dartExceptionMessage = Objects.requireNonNull(call.argument("exception"));
            final List<Map<String, String>> errorElements = Objects.requireNonNull(call.argument("stackTraceElements"));

            final Map<String, Object> map = call.argument("properties");

            if (map == null || map.size() == 0) {
                UXCam.reportExceptionEvent(parseToException(dartExceptionMessage, errorElements));
            } else {
                UXCam.reportExceptionEvent(parseToException(dartExceptionMessage, errorElements), map);
            }
            result.success(null);
        } else if ("startWithConfiguration".equals(call.method)) {
            Map<String, Object> configMap = call.argument("config");
            boolean success = startWithConfig(configMap);
            UXCam.pluginType("flutter", TYPE_VERSION);
            result.success(success);
        } else if ("applyOcclusion".equals(call.method)) {
            Map<String, Object> occlusionMap = call.argument("occlusion");
            UXCamOcclusion occlusion = getOcclusion(occlusionMap);
            UXCam.applyOcclusion(occlusion);
            result.success(true);
        } else if ("removeOcclusion".equals(call.method)) {
            Map<String, Object> occlusionMap = call.argument("occlusion");
            UXCamOcclusion occlusion = getOcclusion(occlusionMap);
            UXCam.removeOcclusion(occlusion);
            result.success(true);
        } else if ("addFrameData".equals(call.method)) {
            long timestamp = call.argument("timestamp");
            String frameData = call.argument("frameData");
            frameDataMap.put(timestamp,frameData);
            result.success(true);
        }
        else {
            result.notImplemented();
        }
    }

    private boolean startWithConfig(Map<String, Object> configMap) {
        try {
            String appKey = (String) configMap.get(USER_APP_KEY);
            Boolean enableMultiSessionRecord = (Boolean) configMap.get(ENABLE_MUTLI_SESSION_RECORD);
            Boolean enableCrashHandling = (Boolean) configMap.get(ENABLE_CRASH_HANDLING);
            Boolean enableAutomaticScreenNameTagging = (Boolean) configMap.get(ENABLE_AUTOMATIC_SCREEN_NAME_TAGGING);
            Boolean enableImprovedScreenCapture = (Boolean) configMap.get(ENABLE_IMPROVED_SCREEN_CAPTURE);
            List<UXCamOcclusion> occlusionList = null;
            if (configMap.get(OCCLUSION) != null) {
                List<Map<String, Object>> occlusionObjects = (List<Map<String, Object>>) configMap.get(OCCLUSION);
                occlusionList = convertToOcclusionList(occlusionObjects);
            }


            UXConfig.Builder uxConfigBuilder = new UXConfig.Builder(appKey);
            if (enableMultiSessionRecord != null)
                uxConfigBuilder.enableMultiSessionRecord(enableMultiSessionRecord);
            if (enableCrashHandling != null)
                uxConfigBuilder.enableCrashHandling(enableCrashHandling);
            if (enableAutomaticScreenNameTagging != null)
                uxConfigBuilder.enableAutomaticScreenNameTagging(enableAutomaticScreenNameTagging);
            if (enableImprovedScreenCapture != null)
                uxConfigBuilder.enableImprovedScreenCapture(enableImprovedScreenCapture);
            if (occlusionList != null) uxConfigBuilder.occlusions(occlusionList);

            UXConfig config = uxConfigBuilder.build();
            UXCam.startWithConfigurationCrossPlatform(activity, config);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private List<UXCamOcclusion> convertToOcclusionList(List<Map<String, Object>> occlusionObjects) {
        List<UXCamOcclusion> occlusionList = new ArrayList<UXCamOcclusion>();
        for (Map<String, Object> occlusionMap : occlusionObjects) {
            UXCamOcclusion occlusion = getOcclusion(occlusionMap);
            if (occlusion != null) occlusionList.add(getOcclusion(occlusionMap));
        }
        return occlusionList;
    }

    private UXCamOcclusion getOcclusion(Map<String, Object> occlusionMap) {
        int typeIndex = (int) occlusionMap.get(TYPE);
        switch (typeIndex) {
            case 2:
                return (UXCamOcclusion) getOverlay(occlusionMap);
            case 3:
                return (UXCamOcclusion) getBlur(occlusionMap);
            default:
                return null;
        }
    }

    private UXCamOverlay getOverlay(Map<String, Object> overlayMap) {
        // get data
        List<String> screens = (List<String>) overlayMap.get(SCREENS);
        Boolean excludeMentionedScreens = (Boolean) overlayMap.get(EXCLUDE_MENTIONED_SCREENS);
        Map<String, Object> configMap = (Map<String, Object>) overlayMap.get(CONFIG);
        Boolean hideGestures = null;
        if (configMap != null) {
            hideGestures = (Boolean) configMap.get(HIDE_GESTURES);
        }

        // set data
        UXCamOverlay.Builder overlayBuilder = new UXCamOverlay.Builder();
        if (screens != null && !screens.isEmpty()) overlayBuilder.screens(screens);
        if (excludeMentionedScreens != null)
            overlayBuilder.excludeMentionedScreens(excludeMentionedScreens);
        if (hideGestures != null) overlayBuilder.withoutGesture(hideGestures);
        return overlayBuilder.build();
    }

    private UXCamBlur getBlur(Map<String, Object> blurMap) {
        // get data
        List<String> screens = (List<String>) blurMap.get(SCREENS);
        Boolean excludeMentionedScreens = (Boolean) blurMap.get(EXCLUDE_MENTIONED_SCREENS);
        Map<String, Object> configMap = (Map<String, Object>) blurMap.get(CONFIG);
        Integer blurRadius = null;
        Boolean hideGestures = null;
        if (configMap != null) {
            blurRadius = (Integer) configMap.get(BLUR_RADIUS);
            hideGestures = (Boolean) configMap.get(HIDE_GESTURES);
        }

        // set data
        UXCamBlur.Builder blurBuilder = new UXCamBlur.Builder();
        if (screens != null && !screens.isEmpty()) blurBuilder.screens(screens);
        if (excludeMentionedScreens != null)
            blurBuilder.excludeMentionedScreens(excludeMentionedScreens);
        if (blurRadius != null) blurBuilder.blurRadius(blurRadius);
        if (hideGestures != null) blurBuilder.withoutGesture(hideGestures);
        return blurBuilder.build();
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

    private Exception parseToException(String dartExceptionMessage, List<Map<String, String>> errorElements) {
        final List<StackTraceElement> elements = new ArrayList<>();
        Exception exception = new FlutterError(dartExceptionMessage);

        for (Map<String, String> errorElement : errorElements) {
            final StackTraceElement stackTraceElement = generateStackTraceElement(errorElement);
            if (stackTraceElement != null) {
                elements.add(stackTraceElement);
            }
        }
        exception.setStackTrace(elements.toArray(new StackTraceElement[0]));
        return exception;
    }

    private StackTraceElement generateStackTraceElement(Map<String, String> errorElement) {
        try {
            String fileName = errorElement.get("file");
            String lineNumber = errorElement.get("line");
            String className = errorElement.get("class");
            String methodName = errorElement.get("method");

            return new StackTraceElement(className == null ? "" : className, methodName, fileName, Integer.parseInt(Objects.requireNonNull(lineNumber)));
        } catch (Exception e) {
            Log.e(TAG, "Unable to generate stack trace element from Dart error.");
            return null;
        }
    }

    private ArrayList<Rect> combineRectDataIfSimilar(Long start, Long end) {

        HashMap<String, JSONArray> widgetDataByKey = new HashMap<>();

        Map<Long, String> effectiveFrameMap = frameDataMap.subMap(start, true, end, true);

        for (Map.Entry<Long, String> entry : effectiveFrameMap.entrySet()) {
            try {
                String frameData = entry.getValue();
                JSONArray list = new JSONArray(frameData);
                for(int i = 0 ; i < list.length(); i++){
                    JSONObject obj = list.getJSONObject(i);
                    String key = obj.optString("key");
                    JSONArray values;
                    if(widgetDataByKey.containsKey(key)){
                        values = widgetDataByKey.get(key);
                    } else {
                        values = new JSONArray();
                    }
                    values.put(obj);
                    widgetDataByKey.put(key, values);
                }
            } catch (JSONException e) {
                Log.e(TAG, "Error parsing JSON", e);
            }
        }

        ArrayList<Rect> result = new ArrayList<Rect>();
        for (Map.Entry<String, JSONArray> entry : widgetDataByKey.entrySet()) {
            JSONArray values = entry.getValue();
            Rect output = new Rect();
            for (int i = 0; i < values.length(); i++) {
                JSONObject obj = values.optJSONObject(i).optJSONObject("point");
                if (obj != null) {
                    Rect rect = new Rect();
                    rect.left = obj.optInt("x0");
                    rect.top = obj.optInt("y0");
                    rect.right = obj.optInt("x1");
                    rect.bottom = obj.optInt("y1");
                    output.union(rect);
                }
            }
            result.add(output);
        }
        return result;
    }

}

