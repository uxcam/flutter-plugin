import 'package:flutter/widgets.dart';

import 'uxcam_element_registry.dart';
import 'uxcam_gesture_interceptor.dart';
import 'uxcam_route_tracker.dart';
import 'uxcam_widget_classifier.dart';
import 'uxcam_widget_extractor.dart';

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

  /// Initialize smart events. Called automatically from `startWithConfiguration`.
  void initialize({bool enableGestureTracking = true}) {
    WidgetsFlutterBinding.ensureInitialized();

    _wasExplicitlyConfigured = true;
    _gestureTrackingEnabled = enableGestureTracking;

    // Handle upgrade from route-tracking-only to full initialization
    if (_routeTrackingOnlyInitialized) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _routeTracker?.dispose();
      _routeTracker = null;
      _routeTrackingOnlyInitialized = false;
      _isInitialized = false;
    }

    if (_isInitialized) return;
    _isInitialized = true;

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
  }

  void _initializeRouteTrackingOnly() {
    WidgetsFlutterBinding.ensureInitialized();

    if (_isInitialized) return;
    _isInitialized = true;
    _routeTrackingOnlyInitialized = true;

    _routeTracker = UXCamRouteTracker();
    _routeTracker!.initialize(onRouteChanged: null);

    WidgetsBinding.instance.addObserver(this);
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
