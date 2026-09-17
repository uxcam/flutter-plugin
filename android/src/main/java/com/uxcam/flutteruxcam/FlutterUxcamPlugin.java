package com.uxcam.flutteruxcam;

import android.app.Activity;
import android.os.Build;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

import com.uxcam.UXCam;
import com.uxcam.screenshot.screenshotTaker.CrossPlatformDelegate;
import com.uxcam.screenshot.screenshotTaker.OcclusionRectRequestListener;
import com.uxcam.screenshot.screenshotTaker.OcclusionReadyCallback;
import com.uxcam.screenshot.screenshotTaker.SceneFrameRequestListener;
import com.uxcam.screenshot.screenshotTaker.SceneFrameReadyCallback;
import com.uxcam.screenshot.screenshotTaker.SceneFrameResponse;
import com.uxcam.internal.FlutterFacade;
import com.uxcam.screenshot.model.UXCamBlur;
import com.uxcam.screenshot.model.UXCamOverlay;
import com.uxcam.screenshot.model.UXCamOcclusion;
import com.uxcam.screenshot.model.UXCamOccludeAllTextFields;
import com.uxcam.screenshot.model.UXCamAITextOcclusion;
import com.uxcam.screenshot.model.MLKitLanguage;
import com.uxcam.datamodel.UXConfig;

import java.util.Collections;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Objects;
import android.graphics.Rect;

import org.json.JSONArray;
import androidx.annotation.NonNull;

/**
 * FlutterUxcamPlugin
 */
public class FlutterUxcamPlugin implements MethodCallHandler, FlutterPlugin, ActivityAware {
    private static final String TYPE_VERSION = "2.10.1";
    public static final String TAG = "FlutterUXCam";
    public static final String USER_APP_KEY = "userAppKey";
    public static final String ENABLE_INTEGRATION_LOGGING = "enableIntegrationLogging";
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
    public static final String RECOGNITION_LANGUAGE = "recognitionLanguage";
    public static final String GAUSSIAN_BLUR = "gaussianBlur";
    public static final String STACK_BLUR = "stackBlur";
    public static final String BOX_BLUR = "boxBlur";
    public static final String BOKEH_BLUR = "bokehBlur";

    /**
     * Plugin registration.
     */
    private static Activity activity;

    private CrossPlatformDelegate delegate;

    // Reflection handles for the delegate's occlusion settings, resolved lazily.
    // The plugin is built against a released UXCam Android SDK that may predate
    // these methods, so they are read reflectively to stay backward compatible
    // (older SDK => absent => feature inactive, never an error).
    private boolean occlusionSettingsReflectionResolved = false;
    private java.lang.reflect.Method textFieldPrivacyGetter;
    private java.lang.reflect.Method currentScreenNameGetter;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private MethodChannel occlusionRequestChannel;
    private BinaryMessenger binaryMessenger;
    private boolean occlusionListenerAttached = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        //general method channel for native and flutter communication
        binaryMessenger = binding.getBinaryMessenger();
        final MethodChannel channel = new MethodChannel(binaryMessenger, "flutter_uxcam");
        channel.setMethodCallHandler(this);

        delegate = UXCam.getDelegate();
    }

    @SuppressWarnings("unchecked")
    private List<Rect> parseRectsFromFlutter(Object result) {
        if (result == null) {
            return Collections.emptyList();
        }

        try {
            List<Map<String, Object>> rectMaps = (List<Map<String, Object>>) result;
            List<Rect> rects = new ArrayList<>(rectMaps.size());

            for (Map<String, Object> rectMap : rectMaps) {
                double left = ((Number) rectMap.get("left")).doubleValue();
                double top = ((Number) rectMap.get("top")).doubleValue();
                double right = ((Number) rectMap.get("right")).doubleValue();
                double bottom = ((Number) rectMap.get("bottom")).doubleValue();

                Rect rect = new Rect(
                        (int) Math.floor(left),
                        (int) Math.floor(top),
                        (int) Math.ceil(right),
                        (int) Math.ceil(bottom)
                );

                if (rect.width() > 0 && rect.height() > 0) {
                    rects.add(rect);
                }
            }

            return rects;
        } catch (Exception e) {
            Log.e(TAG, "[Occlusion] Failed to parse rects: " + e.getMessage());
            return Collections.emptyList();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }

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
        } else if (call.method.equals("registerEngine")) {
            attachOcclusionListenerIfNeeded();
            result.success(true);
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
            startWithConfig(configMap, result);
            UXCam.pluginType("flutter", TYPE_VERSION);
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
        } else if ("appendGestureContent".equals(call.method)) {
            double x = call.argument("x");
            double y = call.argument("y");
            String gestureContent = call.argument("data").toString();
            UXCam.appendGestureContent((float)x, (float)y, gestureContent);
            result.success(true);
        }
        else {
            result.notImplemented();
        }
    }

    private void attachOcclusionListenerIfNeeded() {
        if (occlusionListenerAttached) return;
        if (binaryMessenger == null) return;

        occlusionRequestChannel = new MethodChannel(binaryMessenger, "uxcam_occlusion_request");
        delegate.setListener(new OcclusionRectRequestListener() {
            @Override
            public void requestOcclusionRects(OcclusionReadyCallback callback) {
                mainHandler.post(() -> {
                    Object occlusionArgs = buildOcclusionRequestArgs();
                    occlusionRequestChannel.invokeMethod("requestOcclusionRects", occlusionArgs, new Result() {
                        @Override
                        public void success(Object result) {
                            List<Rect> rects = parseRectsFromFlutter(result);
                            callback.onRectsReady(rects);
                        }

                        @Override
                        public void error(String errorCode, String errorMessage, Object errorDetails) {
                            callback.onRectsReady(Collections.emptyList());
                        }

                        @Override
                        public void notImplemented() {
                            callback.onRectsReady(Collections.emptyList());
                        }
                    });
                });
            }
        });
        attachOcclusionConfigListenerIfSupported();
        occlusionListenerAttached = true;
        attachSceneFrameListenerIfNeeded();
    }

    /**
     * Registers for the SDK's verification-time occlusion-configuration push
     * and forwards it to Dart as {@code updateOcclusionConfiguration} — the
     * authoritative config layer there (config always outranks the manual API),
     * delivered before the first capture so config-driven text-field occlusion
     * is active from the first frame.
     *
     * Reflection + dynamic proxy on purpose: the plugin compiles against a
     * released UXCam SDK that may predate the listener. Older SDK ⇒ classes
     * absent ⇒ silently skipped, feature stays inactive, never an error. The
     * SDK side is sticky, so registering after verification still replays the
     * last config.
     */
    private void attachOcclusionConfigListenerIfSupported() {
        if (delegate == null || occlusionRequestChannel == null) return;
        try {
            Class<?> listenerClass = Class.forName(
                    "com.uxcam.screenshot.screenshotTaker.CrossPlatformDelegate$TextFieldPrivacyListener");
            java.lang.reflect.Method setter = delegate.getClass()
                    .getMethod("setTextFieldPrivacyListener", listenerClass);
            Object listenerProxy = java.lang.reflect.Proxy.newProxyInstance(
                    listenerClass.getClassLoader(),
                    new Class<?>[]{listenerClass},
                    (proxy, method, args) -> {
                        switch (method.getName()) {
                            case "onTextFieldPrivacy":
                                if (args != null && args.length == 1) {
                                    forwardTextFieldPrivacyStatement(args[0]);
                                }
                                return null;
                            case "hashCode":
                                return System.identityHashCode(proxy);
                            case "equals":
                                return proxy == args[0];
                            case "toString":
                                return "FlutterUxcamTextFieldPrivacyListener";
                            default:
                                return null;
                        }
                    });
            setter.invoke(delegate, listenerProxy);
        } catch (Throwable ignored) {
            // Older UXCam SDK without the configuration push — config-driven
            // activation falls back to the per-capture args.
        }
    }

    /**
     * Flattens the SDK's {@code TextFieldPrivacyStatement} into the
     * {@code updateOcclusionConfiguration} shape the Dart layer already consumes.
     *
     * Read reflectively because the statement class ships with the same SDK
     * revision as the listener above — if that lookup succeeded the getters exist,
     * but the reflection keeps the plugin decoupled from the SDK's compile-time API.
     *
     * The statement's three-valued {@code privacy} maps to the Dart master switch:
     * {@code OCCLUDE} ⇒ {@code true}, {@code RECORD} ⇒ an explicit {@code false},
     * {@code UNSPECIFIED} ⇒ the key omitted so Dart clears its config layer and the
     * manual API stays in control.
     */
    private void forwardTextFieldPrivacyStatement(Object statement) {
        if (statement == null) return;
        Object occludeAllTextFields = null; // null => UNSPECIFIED => key omitted
        Object screens = null;
        Object excludeMentionedScreens = Boolean.FALSE;
        try {
            Object privacy = statement.getClass().getMethod("getPrivacy").invoke(statement);
            String privacyName = privacy == null ? "UNSPECIFIED" : privacy.toString();
            if ("OCCLUDE".equals(privacyName)) {
                occludeAllTextFields = Boolean.TRUE;
            } else if ("RECORD".equals(privacyName)) {
                occludeAllTextFields = Boolean.FALSE;
            }
            screens = statement.getClass().getMethod("getScreens").invoke(statement);
            excludeMentionedScreens =
                    statement.getClass().getMethod("getExcludeMentionedScreens").invoke(statement);
        } catch (Throwable ignored) {
            // Statement shape differs from what we expect — forward whatever resolved.
        }
        forwardOcclusionConfiguration(occludeAllTextFields, screens, excludeMentionedScreens);
    }

    private void forwardOcclusionConfiguration(Object occludeAllTextFields, Object screens, Object excludeMentionedScreens) {
        Map<String, Object> args = new HashMap<>();
        // Key omitted when the config did not specify the setting (null): the
        // Dart side then clears its config layer so the manual API stays usable.
        if (occludeAllTextFields instanceof Boolean) {
            args.put("occludeAllTextFields", occludeAllTextFields);
        }
        List<String> screenNames = new ArrayList<>();
        if (screens instanceof List) {
            for (Object screen : (List<?>) screens) {
                if (screen instanceof String) screenNames.add((String) screen);
            }
        }
        args.put("screens", screenNames);
        args.put("excludeMentionedScreens",
                excludeMentionedScreens instanceof Boolean ? excludeMentionedScreens : Boolean.FALSE);
        mainHandler.post(() ->
                occlusionRequestChannel.invokeMethod("updateOcclusionConfiguration", args));
    }

    /**
     * Reads the native-resolved occlusion settings off the delegate and packages
     * them as method-channel arguments for the Dart layer.
     *
     * Reflection is deliberate: this plugin is compiled against a released UXCam
     * Android SDK that may predate these delegate methods. When they are absent
     * (older SDK) we return {@code null} so the request is sent with no settings —
     * the auto-textfield feature simply stays inactive, with no error. When
     * present (newer SDK) the resolved flag is forwarded and the Dart side
     * activates the text-field scan. The lookups are cached after the first call.
     */
    private Map<String, Object> buildOcclusionRequestArgs() {
        if (delegate == null) return null;

        if (!occlusionSettingsReflectionResolved) {
            occlusionSettingsReflectionResolved = true;
            try {
                textFieldPrivacyGetter = delegate.getClass().getMethod("getTextFieldPrivacy");
            } catch (Throwable ignored) {
                textFieldPrivacyGetter = null;
            }
            try {
                currentScreenNameGetter = delegate.getClass().getMethod("getCurrentScreenName");
            } catch (Throwable ignored) {
                currentScreenNameGetter = null;
            }
        }

        if (textFieldPrivacyGetter == null) return null;

        try {
            // Resolved per-frame value is the three-valued TextFieldPrivacy enum,
            // already coerced to OCCLUDE/RECORD natively. Only OCCLUDE masks.
            Object value = textFieldPrivacyGetter.invoke(delegate);
            if (value == null) return null;

            Map<String, Object> args = new HashMap<>();
            args.put("occludeAllTextFields", "OCCLUDE".equals(value.toString()));
            if (currentScreenNameGetter != null) {
                Object screen = currentScreenNameGetter.invoke(delegate);
                if (screen instanceof String) {
                    args.put("currentScreen", screen);
                }
            }
            return args;
        } catch (Throwable ignored) {
            return null;
        }
    }

    private void startWithConfig(Map<String, Object> configMap, Result callback) {
        try {
            addListener(callback);
            String appKey = (String) configMap.get(USER_APP_KEY);
            Boolean enableIntegrationLogging = (Boolean) configMap.get(ENABLE_INTEGRATION_LOGGING);
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
            if (enableIntegrationLogging != null)
                uxConfigBuilder.enableIntegrationLogging(enableIntegrationLogging);
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
        } catch (Exception e) {
            e.printStackTrace();
            callback.success(false);
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
            case 5:
                return (UXCamOcclusion) getAITextOcclusion(occlusionMap);
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

    private UXCamAITextOcclusion getAITextOcclusion(Map<String, Object> occlusionMap) {
        // get data
        List<String> screens = (List<String>) occlusionMap.get(SCREENS);
        Boolean excludeMentionedScreens = (Boolean) occlusionMap.get(EXCLUDE_MENTIONED_SCREENS);
        Map<String, Object> configMap = (Map<String, Object>) occlusionMap.get(CONFIG);
        Boolean hideGestures = null;
        List<String> recognitionLanguages = null;
        if (configMap != null) {
            hideGestures = (Boolean) configMap.get(HIDE_GESTURES);
            recognitionLanguages = (List<String>) configMap.get(RECOGNITION_LANGUAGE);
        }

        // set data
        UXCamAITextOcclusion.Builder occlusionBuilder = new UXCamAITextOcclusion.Builder();
        if (screens != null && !screens.isEmpty()) occlusionBuilder.screens(screens);
        if (excludeMentionedScreens != null)
            occlusionBuilder.excludeMentionedScreens(excludeMentionedScreens);
        if (hideGestures != null) occlusionBuilder.withoutGesture(hideGestures);
        if (recognitionLanguages != null && !recognitionLanguages.isEmpty())
            occlusionBuilder.language(getMLKitLanguage(recognitionLanguages.get(0)));
        return occlusionBuilder.build();
    }

    private MLKitLanguage getMLKitLanguage(String language) {
        String code = language.toLowerCase();
        if (code.startsWith("zh")) return MLKitLanguage.CHINESE;
        if (code.startsWith("ja")) return MLKitLanguage.JAPANESE;
        if (code.startsWith("ko")) return MLKitLanguage.KOREAN;
        if (code.startsWith("hi") || code.startsWith("mr")
                || code.startsWith("ne") || code.startsWith("sa"))
            return MLKitLanguage.DEVANAGARI;
        return MLKitLanguage.LATIN;
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

    // -------------------------------------------------------------------------------------------
    // Scene frames: Dart renders the frame, the SDK records it.
    //
    // Native capture of a Flutter screen has to read back a GPU surface and then ask separately for
    // the occlusion rects, so the geometry can describe a different moment than the pixels. Dart
    // knows both at once, and it is the only side that can see Flutter's own widgets at all.
    //
    // This class is a transport and nothing more: it moves the payload across and leaves every
    // judgement about whether the payload is usable to the SDK, where it is unit-testable.
    // -------------------------------------------------------------------------------------------

    private boolean sceneFrameListenerAttached = false;

    private void attachSceneFrameListenerIfNeeded() {
        if (sceneFrameListenerAttached) return;
        if (binaryMessenger == null || delegate == null || occlusionRequestChannel == null) return;

        try {
            delegate.setSceneFrameListener(new SceneFrameRequestListener() {
                @Override
                public void requestSceneFrame(int targetWidthPx, boolean includePixels,
                                              SceneFrameReadyCallback callback) {
                    mainHandler.post(() -> {
                        Map<String, Object> args = new HashMap<>();
                        args.put("targetWidth", (double) targetWidthPx);
                        args.put("includePixels", includePixels);
                        occlusionRequestChannel.invokeMethod("requestSceneFrame", args, new Result() {
                            @Override
                            public void success(Object result) {
                                SceneFrameResponse response = parseSceneFrameResponse(result);
                                if (response == null) {
                                    callback.onSceneFrameFailed("unparseable scene response");
                                } else {
                                    callback.onSceneFrameReady(response);
                                }
                            }

                            @Override
                            public void error(String errorCode, String errorMessage, Object errorDetails) {
                                // Dart throws UNSUPPORTED for a method it does not implement. That is
                                // a capability fact — the SDK stops asking and keeps capturing
                                // natively. Anything else means it was asked and could not answer.
                                if ("UNSUPPORTED".equals(errorCode)) {
                                    callback.onSceneFrameUnsupported();
                                } else {
                                    callback.onSceneFrameFailed(errorCode == null ? "error" : errorCode);
                                }
                            }

                            @Override
                            public void notImplemented() {
                                callback.onSceneFrameUnsupported();
                            }
                        });
                    });
                }
            });
            sceneFrameListenerAttached = true;
        } catch (NoSuchMethodError | NoClassDefFoundError e) {
            // The app resolved an older com.uxcam:uxcam than this plugin was built against. Scene
            // frames simply do not exist there; the legacy rect path above still works.
            Log.w(TAG, "[SceneFrame] native SDK has no scene-frame support; using legacy occlusion rects");
        }
    }

    /**
     * Converts the Dart payload into the SDK's value type.
     *
     * <p>Geometry and pixels are judged independently, matching iOS: unusable rects do not discard a
     * usable raster, they mark the metadata so the SDK can cover the frame while still recording a
     * real one. Likewise a missing raster with good rects is a normal outcome, not an error.</p>
     *
     * <p>The {@code bytes.length == pixelWidth * pixelHeight * 4} check deliberately lives in the
     * SDK rather than here.</p>
     */
    @SuppressWarnings("unchecked")
    static SceneFrameResponse parseSceneFrameResponse(Object result) {
        if (!(result instanceof Map)) return null;
        Map<String, Object> map = (Map<String, Object>) result;

        int metadataStatus = SceneFrameResponse.METADATA_VALID;
        List<android.graphics.RectF> rects = new ArrayList<>();
        int rectUnits = SceneFrameResponse.UNITS_DEVICE_PIXELS;

        Object rectsObject = map.get("rects");
        if (rectsObject instanceof List) {
            for (Object entry : (List<?>) rectsObject) {
                if (!(entry instanceof Map)) {
                    metadataStatus = SceneFrameResponse.METADATA_MALFORMED;
                    rects.clear();
                    break;
                }
                Map<?, ?> rectMap = (Map<?, ?>) entry;

                // The rect key shape is what identifies the units, not the payload's
                // "coordinateSpace" string: Dart stamps that field with the iOS answer on every
                // platform while its Android encoder emits device pixels, so the two disagree.
                Number left = number(rectMap, "left");
                Number x0 = number(rectMap, "x0");
                Number top, right, bottom;
                if (left != null) {
                    rectUnits = SceneFrameResponse.UNITS_DEVICE_PIXELS;
                    top = number(rectMap, "top");
                    right = number(rectMap, "right");
                    bottom = number(rectMap, "bottom");
                } else if (x0 != null) {
                    rectUnits = SceneFrameResponse.UNITS_LOGICAL_POINTS;
                    left = x0;
                    top = number(rectMap, "y0");
                    right = number(rectMap, "x1");
                    bottom = number(rectMap, "y1");
                } else {
                    metadataStatus = SceneFrameResponse.METADATA_MALFORMED;
                    rects.clear();
                    break;
                }

                if (top == null || right == null || bottom == null
                        || right.floatValue() < left.floatValue()
                        || bottom.floatValue() < top.floatValue()) {
                    metadataStatus = SceneFrameResponse.METADATA_MALFORMED;
                    rects.clear();
                    break;
                }
                rects.add(new android.graphics.RectF(
                        left.floatValue(), top.floatValue(), right.floatValue(), bottom.floatValue()));
            }
        } else if (rectsObject != null) {
            metadataStatus = SceneFrameResponse.METADATA_MALFORMED;
        }

        Number logicalWidth = number(map, "logicalWidth");
        Number logicalHeight = number(map, "logicalHeight");
        Number pixelWidth = number(map, "pixelWidth");
        Number pixelHeight = number(map, "pixelHeight");
        Object bytesObject = map.get("bytes");
        byte[] bytes = (bytesObject instanceof byte[]) ? (byte[]) bytesObject : null;

        // Pixels are all-or-nothing. A partial set of pixel fields is not malformed geometry — it
        // just means there is no usable raster, so native capture supplies one.
        if (bytes == null || pixelWidth == null || pixelHeight == null
                || logicalWidth == null || logicalHeight == null) {
            bytes = null;
        }

        // Reference size describes the logical-point space, so it only applies to those rects.
        Number referenceWidth = number(map, "referenceWidth");
        Number referenceHeight = number(map, "referenceHeight");

        return new SceneFrameResponse(
                bytes,
                bytes == null ? 0 : pixelWidth.intValue(),
                bytes == null ? 0 : pixelHeight.intValue(),
                logicalWidth == null ? 0f : logicalWidth.floatValue(),
                logicalHeight == null ? 0f : logicalHeight.floatValue(),
                rects,
                rectUnits,
                referenceWidth == null ? 0f : referenceWidth.floatValue(),
                referenceHeight == null ? 0f : referenceHeight.floatValue(),
                metadataStatus);
    }

    private static Number number(Map<?, ?> map, String key) {
        Object value = map.get(key);
        return (value instanceof Number) ? (Number) value : null;
    }
}
