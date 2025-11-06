import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// Singleton lifecycle manager to prevent multiple observer registrations
/// This solves FigApplicationStateMonitor errors on iOS by centralizing lifecycle management
class UXCamLifecycleManager with WidgetsBindingObserver {
  static final UXCamLifecycleManager _instance = UXCamLifecycleManager._internal();
  factory UXCamLifecycleManager() => _instance;
  UXCamLifecycleManager._internal();
  
  bool _isInitialized = false;
  AppLifecycleState? _currentState;
  AppLifecycleState? _previousState;
  Timer? _debounceTimer;
  final Set<VoidCallback> _listeners = {};
  
  // iOS-specific optimizations
  DateTime? _lastStateChangeTime;
  static const Duration _minStateChangeInterval = Duration(milliseconds: 500);
  static const Duration _iosStabilizationDelay = Duration(milliseconds: 100);
  
  // Track rapid state changes (iOS issue)
  int _rapidStateChangeCount = 0;
  Timer? _rapidStateResetTimer;
  
  void initialize() {
    if (_isInitialized) {
      print('[UXCam] Lifecycle manager already initialized, skipping');
      return;
    }
    
    print('[UXCam] Initializing lifecycle manager');
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    _currentState = WidgetsBinding.instance.lifecycleState;
    _lastStateChangeTime = DateTime.now();
  }
  
  void dispose() {
    if (!_isInitialized) return;
    
    print('[UXCam] Disposing lifecycle manager');
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _rapidStateResetTimer?.cancel();
    _listeners.clear();
    _isInitialized = false;
    _currentState = null;
    _previousState = null;
  }
  
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore duplicate states
    if (state == _currentState) {
      return;
    }
    
    final now = DateTime.now();
    
    // iOS: Detect and handle rapid state changes
    if (Platform.isIOS) {
      if (_lastStateChangeTime != null) {
        final timeSinceLastChange = now.difference(_lastStateChangeTime!);
        if (timeSinceLastChange < Duration(milliseconds: 100)) {
          _rapidStateChangeCount++;
          
          // If too many rapid changes, ignore some
          if (_rapidStateChangeCount > 3) {
            print('[UXCam] Ignoring rapid state change to prevent FigApplicationStateMonitor spam');
            
            // Reset counter after delay
            _rapidStateResetTimer?.cancel();
            _rapidStateResetTimer = Timer(Duration(seconds: 1), () {
              _rapidStateChangeCount = 0;
            });
            
            return;
          }
        } else {
          _rapidStateChangeCount = 0;
        }
      }
    }
    
    _lastStateChangeTime = now;
    _previousState = _currentState;
    _currentState = state;
    
    print('[UXCam] Lifecycle state changed: $_previousState -> $_currentState');
    
    // Debounce state changes to prevent FigApplicationStateMonitor spam
    _debounceTimer?.cancel();
    
    if (Platform.isIOS) {
      // iOS needs more aggressive debouncing
      _debounceTimer = Timer(_minStateChangeInterval, () {
        _handleStateChange(state);
      });
    } else {
      // Android can handle changes faster
      _debounceTimer = Timer(Duration(milliseconds: 100), () {
        _handleStateChange(state);
      });
    }
  }
  
  void _handleStateChange(AppLifecycleState state) {
    // Verify state hasn't changed during debounce
    if (state != _currentState) {
      print('[UXCam] State changed during debounce, ignoring outdated state');
      return;
    }
    
    if (Platform.isIOS) {
      _handleIOSStateChange(state);
    } else {
      _handleAndroidStateChange(state);
    }
  }
  
  void _handleIOSStateChange(AppLifecycleState state) {
    // iOS-specific handling to minimize FigApplicationStateMonitor triggers
    switch (state) {
      case AppLifecycleState.resumed:
        // Delay resume to let iOS stabilize
        Future.delayed(_iosStabilizationDelay, () {
          if (_currentState == AppLifecycleState.resumed) {
            _onResumed();
          }
        });
        break;
        
      case AppLifecycleState.paused:
        _onPaused();
        break;
        
      case AppLifecycleState.inactive:
        // iOS: Don't handle inactive state to reduce Fig errors
        // Inactive is transitional and handling it causes issues
        print('[UXCam] iOS: Ignoring inactive state to prevent FigApplicationStateMonitor issues');
        break;
        
      case AppLifecycleState.detached:
        _onDetached();
        break;
        
      case AppLifecycleState.hidden:
        // iOS 13+ hidden state
        print('[UXCam] iOS: App hidden');
        _onPaused();
        break;
    }
  }
  
  void _handleAndroidStateChange(AppLifecycleState state) {
    // Android can handle all states normally
    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
        break;
        
      case AppLifecycleState.paused:
        _onPaused();
        break;
        
      case AppLifecycleState.inactive:
        _onInactive();
        break;
        
      case AppLifecycleState.detached:
        _onDetached();
        break;
        
      case AppLifecycleState.hidden:
        _onPaused();
        break;
    }
  }
  
  void _onResumed() {
    print('[UXCam] App resumed');
    
    // Only resume recording if we were previously paused
    if (_previousState == AppLifecycleState.paused || 
        _previousState == AppLifecycleState.hidden) {
      
      // Delay for iOS to stabilize
      if (Platform.isIOS) {
        Future.delayed(Duration(milliseconds: 200), () {
          if (_currentState == AppLifecycleState.resumed) {
            FlutterUxcam.resumeScreenRecording().catchError((e) {
              print('[UXCam] Error resuming recording: $e');
            });
          }
        });
      } else {
        FlutterUxcam.resumeScreenRecording().catchError((e) {
          print('[UXCam] Error resuming recording: $e');
        });
      }
    }
    
    _notifyListeners();
  }
  
  void _onPaused() {
    print('[UXCam] App paused');
    
    // Pause recording immediately
    FlutterUxcam.pauseScreenRecording().catchError((e) {
      print('[UXCam] Error pausing recording: $e');
    });
    
    _notifyListeners();
  }
  
  void _onInactive() {
    print('[UXCam] App inactive (Android)');
    // Android-specific inactive handling
    _notifyListeners();
  }
  
  void _onDetached() {
    print('[UXCam] App detached');
    
    // Upload data before app terminates
    FlutterUxcam.stopSessionAndUploadData().catchError((e) {
      print('[UXCam] Error stopping session: $e');
    });
    
    _notifyListeners();
  }
  
  void _notifyListeners() {
    // Create a copy to avoid concurrent modification
    final listeners = Set<VoidCallback>.from(_listeners);
    for (final listener in listeners) {
      try {
        listener();
      } catch (e) {
        print('[UXCam] Error notifying listener: $e');
      }
    }
  }
  
  // Public getters
  AppLifecycleState? get currentState => _currentState;
  AppLifecycleState? get previousState => _previousState;
  bool get isInForeground => _currentState == AppLifecycleState.resumed;
  bool get isInBackground => _currentState == AppLifecycleState.paused || 
                              _currentState == AppLifecycleState.hidden;
  
  // Debug info
  Map<String, dynamic> get debugInfo => {
    'isInitialized': _isInitialized,
    'currentState': _currentState?.toString(),
    'previousState': _previousState?.toString(),
    'listenerCount': _listeners.length,
    'rapidStateChangeCount': _rapidStateChangeCount,
    'isInForeground': isInForeground,
  };
}