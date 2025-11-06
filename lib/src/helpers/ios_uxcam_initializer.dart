import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// iOS-specific initialization helper to prevent FigApplicationStateMonitor errors
class IOSUXCamInitializer {
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static Completer<bool>? _initCompleter;
  
  // iOS-specific delays to prevent Fig framework issues
  static const Duration _preInitDelay = Duration(milliseconds: 500);
  static const Duration _postInitDelay = Duration(milliseconds: 200);
  static const Duration _schematicDelay = Duration(milliseconds: 100);
  static const Duration _bridgeAttachDelay = Duration(milliseconds: 300);
  
  /// Initialize UXCam with iOS-specific optimizations
  /// This prevents most FigApplicationStateMonitor errors
  static Future<bool> initialize(FlutterUxConfig config) async {
    // Return if already initialized
    if (_isInitialized) {
      print('[UXCam iOS] Already initialized');
      return true;
    }
    
    // Wait for ongoing initialization
    if (_isInitializing && _initCompleter != null) {
      print('[UXCam iOS] Initialization in progress, waiting...');
      return await _initCompleter!.future;
    }
    
    _isInitializing = true;
    _initCompleter = Completer<bool>();
    
    try {
      if (Platform.isIOS) {
        print('[UXCam iOS] Starting iOS-specific initialization');
        final success = await _initializeIOS(config);
        _isInitialized = success;
        _initCompleter!.complete(success);
        return success;
      } else {
        // Regular initialization for Android
        print('[UXCam] Starting Android initialization');
        final success = await FlutterUxcam.startWithConfiguration(config);
        _isInitialized = success;
        _initCompleter!.complete(success);
        return success;
      }
    } catch (e) {
      print('[UXCam iOS] Initialization error: $e');
      _initCompleter!.complete(false);
      return false;
    } finally {
      _isInitializing = false;
    }
  }
  
  static Future<bool> _initializeIOS(FlutterUxConfig config) async {
    try {
      // Step 1: Let iOS app state stabilize
      print('[UXCam iOS] Step 1: Waiting for iOS to stabilize...');
      await Future.delayed(_preInitDelay);
      
      // Step 2: Clear any previous state
      print('[UXCam iOS] Step 2: Clearing previous state...');
      await _clearPreviousState();
      
      // Step 3: Setup schematic recordings first
      print('[UXCam iOS] Step 3: Setting up schematic recordings...');
      await _setupSchematicRecordings();
      
      // Step 4: Initialize UXCam
      print('[UXCam iOS] Step 4: Initializing UXCam SDK...');
      bool success = await _initializeSDK(config);
      
      if (!success) {
        print('[UXCam iOS] Step 4 failed, retrying...');
        // Retry once after delay
        await Future.delayed(Duration(seconds: 1));
        success = await _initializeSDK(config);
      }
      
      if (success) {
        // Step 5: Attach bridge after successful init
        print('[UXCam iOS] Step 5: Attaching bridge...');
        await Future.delayed(_bridgeAttachDelay);
        await _attachBridge();
        
        print('[UXCam iOS] Initialization complete!');
        return true;
      } else {
        print('[UXCam iOS] Initialization failed');
        return false;
      }
      
    } catch (e) {
      print('[UXCam iOS] Error during iOS initialization: $e');
      return false;
    }
  }
  
  static Future<void> _clearPreviousState() async {
    try {
      final channel = MethodChannel('flutter_uxcam');
      
      // Try to clear native state
      try {
        await channel.invokeMethod('clearState');
      } catch (e) {
        // Method might not exist, that's ok
      }
      
      // Force a clean lifecycle state
      await _resetLifecycleState();
      
    } catch (e) {
      print('[UXCam iOS] Warning: Could not clear previous state: $e');
    }
  }
  
  static Future<void> _resetLifecycleState() async {
    try {
      // This helps reset FigApplicationStateMonitor
      const duration = Duration(milliseconds: 50);
      await SystemChannels.lifecycle.send('AppLifecycleState.paused');
      await Future.delayed(duration);
      await SystemChannels.lifecycle.send('AppLifecycleState.inactive');
      await Future.delayed(duration);
      await SystemChannels.lifecycle.send('AppLifecycleState.resumed');
    } catch (e) {
      // Ignore errors, this is best-effort
    }
  }
  
  static Future<void> _setupSchematicRecordings() async {
    try {
      // Enable schematic recordings for iOS
      await FlutterUxcam.optIntoSchematicRecordings();
      
      // Small delay after opting in to let iOS process
      await Future.delayed(_schematicDelay);
      
      print('[UXCam iOS] Schematic recordings enabled');
    } catch (e) {
      print('[UXCam iOS] Warning: Schematic recordings setup failed: $e');
      // Non-fatal, continue initialization
    }
  }
  
  static Future<bool> _initializeSDK(FlutterUxConfig config) async {
    try {
      // Add iOS-specific config if needed
      if (config.enableAdvancedGestureRecognition == null) {
        config.enableAdvancedGestureRecognition = false; // Reduce overhead on iOS
      }
      
      final success = await FlutterUxcam.initailizeUXCam(config);
      
      if (success) {
        // Post-init delay for iOS
        await Future.delayed(_postInitDelay);
      }
      
      return success;
    } catch (e) {
      print('[UXCam iOS] SDK initialization error: $e');
      return false;
    }
  }
  
  static Future<void> _attachBridge() async {
    try {
      await FlutterUxcam.attachBridge();
      print('[UXCam iOS] Bridge attached successfully');
    } catch (e) {
      print('[UXCam iOS] Warning: Bridge attachment failed: $e');
      // Non-fatal, recording might still work
    }
  }
  
  /// Call this when app is about to terminate
  static Future<void> cleanup() async {
    if (!_isInitialized) return;
    
    try {
      print('[UXCam iOS] Cleaning up...');
      
      // Stop session and upload
      await FlutterUxcam.stopSessionAndUploadData();
      
      // Clear state
      _isInitialized = false;
      _isInitializing = false;
      _initCompleter = null;
      
    } catch (e) {
      print('[UXCam iOS] Cleanup error: $e');
    }
  }
  
  /// Check if initialization is complete
  static bool get isInitialized => _isInitialized;
  
  /// Check if initialization is in progress
  static bool get isInitializing => _isInitializing;
}

/// Helper class to manage iOS-specific recording states
class IOSRecordingManager {
  static bool _isRecording = false;
  static Timer? _recordingCheckTimer;
  static DateTime? _lastPauseTime;
  static DateTime? _lastResumeTime;
  
  // Minimum time between pause/resume to prevent Fig errors
  static const Duration _minPauseResumeInterval = Duration(milliseconds: 500);
  
  /// Safely pause recording with iOS optimizations
  static Future<void> pauseRecording() async {
    final now = DateTime.now();
    
    // Check if we paused too recently
    if (_lastPauseTime != null) {
      final timeSincePause = now.difference(_lastPauseTime!);
      if (timeSincePause < _minPauseResumeInterval) {
        print('[UXCam iOS] Ignoring pause - too soon since last pause');
        return;
      }
    }
    
    // Check if we resumed too recently
    if (_lastResumeTime != null) {
      final timeSinceResume = now.difference(_lastResumeTime!);
      if (timeSinceResume < _minPauseResumeInterval) {
        print('[UXCam iOS] Delaying pause - too soon since resume');
        await Future.delayed(_minPauseResumeInterval - timeSinceResume);
      }
    }
    
    try {
      await FlutterUxcam.pauseScreenRecording();
      _isRecording = false;
      _lastPauseTime = DateTime.now();
      print('[UXCam iOS] Recording paused');
    } catch (e) {
      print('[UXCam iOS] Error pausing recording: $e');
    }
  }
  
  /// Safely resume recording with iOS optimizations
  static Future<void> resumeRecording() async {
    final now = DateTime.now();
    
    // Check if we resumed too recently
    if (_lastResumeTime != null) {
      final timeSinceResume = now.difference(_lastResumeTime!);
      if (timeSinceResume < _minPauseResumeInterval) {
        print('[UXCam iOS] Ignoring resume - too soon since last resume');
        return;
      }
    }
    
    // Check if we paused too recently
    if (_lastPauseTime != null) {
      final timeSincePause = now.difference(_lastPauseTime!);
      if (timeSincePause < _minPauseResumeInterval) {
        print('[UXCam iOS] Delaying resume - too soon since pause');
        await Future.delayed(_minPauseResumeInterval - timeSincePause);
      }
    }
    
    try {
      await FlutterUxcam.resumeScreenRecording();
      _isRecording = true;
      _lastResumeTime = DateTime.now();
      print('[UXCam iOS] Recording resumed');
    } catch (e) {
      print('[UXCam iOS] Error resuming recording: $e');
    }
  }
  
  /// Start monitoring recording state
  static void startMonitoring() {
    if (!Platform.isIOS) return;
    
    _recordingCheckTimer?.cancel();
    _recordingCheckTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      try {
        final isRecording = await FlutterUxcam.isRecording();
        if (isRecording != _isRecording) {
          print('[UXCam iOS] Recording state mismatch. Expected: $_isRecording, Actual: $isRecording');
          _isRecording = isRecording;
        }
      } catch (e) {
        print('[UXCam iOS] Error checking recording state: $e');
      }
    });
  }
  
  /// Stop monitoring
  static void stopMonitoring() {
    _recordingCheckTimer?.cancel();
    _recordingCheckTimer = null;
  }
  
  static bool get isRecording => _isRecording;
}