import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'uxcam_element_registry.dart';
import 'uxcam_gesture_interceptor.dart';
import 'uxcam_route_tracker.dart';
import 'uxcam_widget_classifier.dart';
import 'uxcam_widget_extractor.dart';

class _UXCamBinding extends WidgetsFlutterBinding {
  static WidgetsBinding ensureInitialized() {
    try {
      if (WidgetsBinding.instance is _UXCamBinding) {
        return WidgetsBinding.instance as _UXCamBinding;
      }
    } catch (_) {}
    try {
      return _UXCamBinding();
    } catch (_) {
      return WidgetsBinding.instance;
    }
  }

  @override
  Future<void> performReassemble() async {
    UXCamSmartEvents.notifyHotReload();
    return super.performReassemble();
  }
}

/// Initialization coordinator for automatic gesture tracking.
class UXCamSmartEvents with WidgetsBindingObserver {
  // Use eager singleton to prevent resurrection issues
  static final UXCamSmartEvents _instance = UXCamSmartEvents._internal();
  factory UXCamSmartEvents() => _instance;
  UXCamSmartEvents._internal();

  UXCamGestureInterceptor? _gestureInterceptor;
  UXCamElementRegistry? _elementRegistry;
  UXCamRouteTracker? _routeTracker;
  UXCamWidgetExtractor? _widgetExtractor;

  bool _isInitialized = false;
  bool _gestureTrackingEnabled = true;
  bool _routeTrackingOnlyInitialized = false;
  bool _wasExplicitlyConfigured = false;

  static int _initGeneration = 0;
  int _myGeneration = 0;

  /// Initialize smart events. Called automatically from `startWithConfiguration`.
  void initialize({bool enableGestureTracking = true}) {
    _UXCamBinding.ensureInitialized();

    _wasExplicitlyConfigured = true;
    _gestureTrackingEnabled = enableGestureTracking;

    final canSkip =
        _isInitialized && _myGeneration == _initGeneration && !_routeTrackingOnlyInitialized;
    if (canSkip) return;

    if (_routeTrackingOnlyInitialized) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _routeTracker?.dispose();
      _routeTracker = null;
      _routeTrackingOnlyInitialized = false;
    }

    if (_isInitialized && _myGeneration != _initGeneration) {
      _cleanupForHotReload();
    }

    _isInitialized = true;
    _myGeneration = _initGeneration;

    _elementRegistry = UXCamElementRegistry();
    _routeTracker = UXCamRouteTracker();
    _widgetExtractor = UXCamWidgetExtractor();
    _gestureInterceptor = UXCamGestureInterceptor();

    _elementRegistry!.initialize();
    _routeTracker!.initialize(onRouteChanged: _onRouteChanged);
    _widgetExtractor!.initialize(
      registry: _elementRegistry!,
      routeTracker: _routeTracker!,
    );

    if (_gestureTrackingEnabled) {
      _gestureInterceptor!.initialize(onTap: _onTap);
    }

    WidgetsBinding.instance.addObserver(this);

    if (kDebugMode) {
      _registerHotReloadCallback();
    }
  }

  void _initializeRouteTrackingOnly() {
    _UXCamBinding.ensureInitialized();

    if (_isInitialized) return;
    _isInitialized = true;
    _myGeneration = _initGeneration;
    _routeTrackingOnlyInitialized = true;

    _routeTracker = UXCamRouteTracker();
    _routeTracker!.initialize(onRouteChanged: null);

    WidgetsBinding.instance.addObserver(this);
  }

  void _registerHotReloadCallback() {}

  void _cleanupForHotReload() {
    _gestureInterceptor?.dispose();
    _widgetExtractor?.dispose();
    _routeTracker?.dispose();
    _elementRegistry?.onHotReload();
    _elementRegistry?.dispose();

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}

    _gestureInterceptor = null;
    _widgetExtractor = null;
    _routeTracker = null;
    _elementRegistry = null;

    _isInitialized = false;
    _routeTrackingOnlyInitialized = false;
  }

  static void notifyHotReload() {
    _initGeneration++;
    final restoreTracking = _instance._wasExplicitlyConfigured;
    final trackingEnabled = _instance._gestureTrackingEnabled;
    _instance._cleanupForHotReload();
    if (restoreTracking) {
      _instance.initialize(enableGestureTracking: trackingEnabled);
    }
  }

  void dispose() {
    if (!_isInitialized) return;

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}

    _gestureInterceptor?.dispose();
    _widgetExtractor?.dispose();
    _routeTracker?.dispose();
    _elementRegistry?.dispose();

    _gestureInterceptor = null;
    _widgetExtractor = null;
    _routeTracker = null;
    _elementRegistry = null;

    _isInitialized = false;
    _wasExplicitlyConfigured = false;
    // Don't null out _instance - eager singleton prevents resurrection
  }

  void enable() {
    _gestureTrackingEnabled = true;
    if (_isInitialized && _gestureInterceptor != null) {
      _gestureInterceptor!.enable();
    } else if (_isInitialized && _gestureInterceptor == null) {
      _gestureInterceptor = UXCamGestureInterceptor();
      _gestureInterceptor!.initialize(onTap: _onTap);
    }
  }

  void disable() {
    _gestureTrackingEnabled = false;
    _gestureInterceptor?.disable();
  }

  NavigatorObserver get navigatorObserver {
    if (!_isInitialized) {
      if (_wasExplicitlyConfigured) {
        initialize(enableGestureTracking: _gestureTrackingEnabled);
      } else {
        _initializeRouteTrackingOnly();
      }
    }
    return _routeTracker!.navigatorObserver;
  }

  NavigatorObserver createNestedNavigatorObserver(String navigatorId) {
    if (!_isInitialized) {
      if (_wasExplicitlyConfigured) {
        initialize(enableGestureTracking: _gestureTrackingEnabled);
      } else {
        _initializeRouteTrackingOnly();
      }
    }
    return _routeTracker!.createObserverForNavigator(navigatorId);
  }

  static void registerButtonType(Type type) {
    UXCamWidgetClassifier.registerButtonType(type);
  }

  static void registerFieldType(Type type) {
    UXCamWidgetClassifier.registerFieldType(type);
  }

  static void registerInteractiveType(Type type) {
    UXCamWidgetClassifier.registerInteractiveType(type);
  }

  static void unregisterButtonType(Type type) {
    UXCamWidgetClassifier.unregisterButtonType(type);
  }

  static void unregisterFieldType(Type type) {
    UXCamWidgetClassifier.unregisterFieldType(type);
  }

  static void unregisterInteractiveType(Type type) {
    UXCamWidgetClassifier.unregisterInteractiveType(type);
  }

  static void clearCustomTypes() {
    UXCamWidgetClassifier.clearCustomTypes();
  }

  void _onTap(Offset position, Set<int> hitTargetHashes) {
    if (!_gestureTrackingEnabled) return;
    _widgetExtractor?.extractAndSend(position, hitTargetHashes);
  }

  void _onRouteChanged() {
    _elementRegistry?.onRouteChange();
  }

  bool get isEnabled => _gestureTrackingEnabled;

  bool get isInitialized => _isInitialized;

  int get cacheSize => _elementRegistry?.cacheSize ?? 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _elementRegistry?.onAppResumed();
    }
  }

  @override
  void didHaveMemoryPressure() {
    _elementRegistry?.handleMemoryPressure();
  }
}
