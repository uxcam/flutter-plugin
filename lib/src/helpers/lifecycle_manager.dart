import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';

/// Manages app lifecycle events to prevent memory leaks
/// Automatically cleans up resources when app is paused or terminated
class UXCamLifecycleManager extends WidgetsBindingObserver {
  static UXCamLifecycleManager? _instance;
  bool _isRegistered = false;
  Timer? _periodicCleanupTimer;
  
  // Perform periodic cleanup every 5 minutes to prevent memory accumulation
  static const Duration _cleanupInterval = Duration(minutes: 5);

  UXCamLifecycleManager._();

  static UXCamLifecycleManager get instance {
    _instance ??= UXCamLifecycleManager._();
    return _instance!;
  }

  /// Register lifecycle observer
  void register() {
    if (!_isRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isRegistered = true;
      _startPeriodicCleanup();
    }
  }

  /// Unregister lifecycle observer
  void unregister() {
    if (_isRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isRegistered = false;
      _stopPeriodicCleanup();
    }
  }
  
  /// Start periodic cleanup timer
  void _startPeriodicCleanup() {
    _stopPeriodicCleanup(); // Ensure no duplicate timers
    _periodicCleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _performPeriodicCleanup();
    });
  }
  
  /// Stop periodic cleanup timer
  void _stopPeriodicCleanup() {
    _periodicCleanupTimer?.cancel();
    _periodicCleanupTimer = null;
  }
  
  /// Perform periodic cleanup to prevent memory accumulation
  void _performPeriodicCleanup() {
    try {
      // Clear cached data in channel callback
      // Note: We don't clear the full list, just trim if it's too large
      // This is already handled by the _maxCachedDataSize limit
      
      // Clear cached JSON in occlusion manager
      final manager = OcclusionWrapperManager();
      manager.clearOcclusionRects();
    } catch (e) {
      // Ignore errors during periodic cleanup
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App is in background, perform light cleanup
        _performLightCleanup();
        break;
      case AppLifecycleState.detached:
        // App is being terminated, perform full cleanup
        _performFullCleanup();
        break;
      case AppLifecycleState.resumed:
        // App is back in foreground
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., phone call, switching apps)
        break;
      case AppLifecycleState.hidden:
        // App window is hidden
        break;
    }
  }

  /// Light cleanup when app goes to background
  void _performLightCleanup() {
    try {
      // Clear cached data but keep essential structures
      final manager = OcclusionWrapperManager();
      manager.clearOcclusionRects();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  /// Full cleanup when app is being terminated
  void _performFullCleanup() {
    try {
      // Dispose all UXCam resources
      FlutterUxcam.dispose();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  /// Manual cleanup method
  void cleanup() {
    _performFullCleanup();
  }

  /// Dispose and cleanup this manager
  void dispose() {
    _stopPeriodicCleanup();
    unregister();
    _instance = null;
  }
}

