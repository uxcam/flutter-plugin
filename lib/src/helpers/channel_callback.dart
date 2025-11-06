import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FlutterChannelCallBackName {
  static const pause = "pauseRendering";
  static const resumeWithData = "requestAllOcclusionRects";
  static const captureFrame = "requestOccludedImage"; // New approach
}

class ChannelCallback {
  static bool _isRenderingPaused = false;
  static bool _preventRender = false;
  static List<Map<String, dynamic>> _cachedData = [];
  static bool _isFrameDeferred = false;
  
  // Optimization: Reuse frame deferral state
  static bool _isDeferralActive = false;
  static Completer<void>? _deferralCompleter;
  
  // Frame synchronization optimization
  static int _frameId = 0;
  static Map<int, _FrameData> _frameDataCache = {};
  
  // Performance optimization: Batch deferrals
  static Timer? _deferralTimer;
  static const Duration _minDeferralInterval = Duration(milliseconds: 100);
  static DateTime _lastDeferralTime = DateTime.now();

  static Future<void> handleChannelCallBacks(MethodChannel channel) async {
    // Use longer interval for visibility updates during normal operation
    VisibilityDetectorController.instance.updateInterval = Duration(seconds: 1);
    
    channel.setMethodCallHandler((MethodCall call) async {
      try {
        switch (call.method) {
          case FlutterChannelCallBackName.resumeWithData:
            final data = _cachedData;
            await _resumeRendering();
            return data;
            
          case FlutterChannelCallBackName.pause:
            return await _pauseRendering();
            
          case FlutterChannelCallBackName.captureFrame:
            // Alternative approach: capture frame from Flutter side
            return await _captureFrameWithRects();
            
          default:
            return null;
        }
      } catch (e) {
        print('Error in channel callback: $e');
        // Ensure frame is resumed on error
        if (_isFrameDeferred) {
          WidgetsBinding.instance.allowFirstFrame();
          _isFrameDeferred = false;
        }
        return null;
      }
    });
  }

  // Optimized pause rendering with frame synchronization
  static Future<bool> _pauseRendering() async {
    // Throttle rapid pause requests
    final now = DateTime.now();
    if (now.difference(_lastDeferralTime) < _minDeferralInterval) {
      // If called too soon, wait for current deferral to complete
      if (_deferralCompleter != null && !_deferralCompleter!.isCompleted) {
        await _deferralCompleter!.future;
      }
      return true;
    }
    _lastDeferralTime = now;
    
    if (_isRenderingPaused && _isFrameDeferred) {
      // Already paused and deferred, just update visibility
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      _isRenderingPaused = true;
      _preventRender = true;
      _deferralCompleter = Completer<void>();
      
      // Ensure we're at a stable point before deferring
      await _waitForStableFrame();
      
      // Update visibility detector before pausing
      VisibilityDetectorController.instance.notifyNow();
      
      // Now defer the frame for synchronization
      if (!_isFrameDeferred) {
        // Increment frame ID for tracking
        _frameId++;
        
        // Defer frame - this ensures screenshot and rects are synchronized
        WidgetsBinding.instance.deferFirstFrame();
        _isFrameDeferred = true;
        _isDeferralActive = true;
        
        // Collect occlusion data while frame is deferred
        _cachedData = await _collectOcclusionDataOptimized();
        
        // Store frame data with ID for verification
        _frameDataCache[_frameId] = _FrameData(
          timestamp: DateTime.now(),
          rects: _cachedData,
        );
        
        // Clean old frame data (keep last 5 frames)
        if (_frameDataCache.length > 5) {
          final keysToRemove = _frameDataCache.keys.toList()
            ..sort()
            ..take(_frameDataCache.length - 5);
          for (final key in keysToRemove) {
            _frameDataCache.remove(key);
          }
        }
      }
      
      _deferralCompleter!.complete();
      return true;
      
    } catch (e) {
      print('Error pausing rendering: $e');
      _isRenderingPaused = false;
      _preventRender = false;
      
      if (_isFrameDeferred) {
        WidgetsBinding.instance.allowFirstFrame();
        _isFrameDeferred = false;
        _isDeferralActive = false;
      }
      
      if (_deferralCompleter != null && !_deferralCompleter!.isCompleted) {
        _deferralCompleter!.completeError(e);
      }
      
      return false;
    }
  }

  // Optimized resume with validation
  static Future<bool> _resumeRendering() async {
    if (!_isRenderingPaused) {
      VisibilityDetectorController.instance.notifyNow();
      return true;
    }

    try {
      _isRenderingPaused = false;
      _preventRender = false;
      
      // Resume frame rendering
      if (_isFrameDeferred) {
        // Ensure we have the data before resuming
        if (_cachedData.isEmpty) {
          _cachedData = await _collectOcclusionDataOptimized();
        }
        
        WidgetsBinding.instance.allowFirstFrame();
        _isFrameDeferred = false;
        _isDeferralActive = false;
        
        // Schedule visibility update after frame resumes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          VisibilityDetectorController.instance.notifyNow();
        });
      }
      
      return true;
      
    } catch (e) {
      print('Error resuming rendering: $e');
      _isRenderingPaused = true;
      _preventRender = true;
      return false;
    }
  }

  // Optimized occlusion data collection
  static Future<List<Map<String, dynamic>>> _collectOcclusionDataOptimized() async {
    final instance = OcclusionWrapperManager();
    
    // If frame is deferred, we can collect synchronously
    if (_isFrameDeferred) {
      return instance.fetchOcclusionRects();
    }
    
    // Otherwise, wait for next frame boundary
    final completer = Completer<List<Map<String, dynamic>>>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final rects = instance.fetchOcclusionRects();
        completer.complete(rects);
      } catch (e) {
        completer.completeError(e);
      }
    });
    
    return await completer.future.timeout(
      Duration(milliseconds: 50),
      onTimeout: () => instance.fetchOcclusionRects(),
    );
  }

  // Alternative approach: Capture frame from Flutter side with RepaintBoundary
  static Future<Map<String, dynamic>> _captureFrameWithRects() async {
    try {
      // This approach uses RepaintBoundary to capture the frame from Flutter
      // ensuring perfect synchronization without frame deferral
      
      final instance = OcclusionWrapperManager();
      
      // Collect rects at current frame
      final rects = instance.fetchOcclusionRects();
      
      // Try to capture current frame using RepaintBoundary if available
      ui.Image? frameImage;
      
      // Look for root RepaintBoundary (would need to be added to app)
      final binding = WidgetsBinding.instance;
      if (binding.rootElement != null) {
        final renderObject = binding.rootElement!.renderObject;
        if (renderObject is RenderRepaintBoundary) {
          try {
            frameImage = await renderObject.toImage(
              pixelRatio: WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio, // ui.window.devicePixelRatio,
            );
          } catch (e) {
            print('Failed to capture frame image: $e');
          }
        }
      }
      
      // Convert image to bytes if captured
      Uint8List? imageBytes;
      if (frameImage != null) {
        final byteData = await frameImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        imageBytes = byteData?.buffer.asUint8List();
      }
      
      return {
        'frameId': _frameId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'rects': rects,
        'frameImage': imageBytes, // Optional: frame captured from Flutter
      };
      
    } catch (e) {
      print('Error capturing frame with rects: $e');
      return {
        'frameId': _frameId,
        'rects': [],
        'error': e.toString(),
      };
    }
  }

  // Helper to wait for stable frame
  static Future<void> _waitForStableFrame() async {
    // Check if we're in a build phase
    if (WidgetsBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      // Wait for current frame to complete
      await WidgetsBinding.instance.endOfFrame;
    }
    
    // Additional small delay to ensure stability
    await Future.delayed(Duration(microseconds: 100));
  }

  // Get frame synchronization status
  static Map<String, dynamic> getFrameSyncStatus() {
    return {
      'isFrameDeferred': _isFrameDeferred,
      'isRenderingPaused': _isRenderingPaused,
      'currentFrameId': _frameId,
      'cachedFrames': _frameDataCache.keys.toList(),
      'isDeferralActive': _isDeferralActive,
    };
  }

  // Clean up method
  static void cleanup() {
    if (_isFrameDeferred) {
      WidgetsBinding.instance.allowFirstFrame();
      _isFrameDeferred = false;
    }
    _isRenderingPaused = false;
    _preventRender = false;
    _cachedData.clear();
    _frameDataCache.clear();
    _deferralCompleter = null;
    _deferralTimer?.cancel();
    _deferralTimer = null;
  }
}

// Helper class to store frame data
class _FrameData {
  final DateTime timestamp;
  final List<Map<String, dynamic>> rects;
  
  _FrameData({
    required this.timestamp,
    required this.rects,
  });
}

// Extension for scheduler phase checking
extension on WidgetsBinding {
  SchedulerPhase get schedulerPhase {
    // Access the scheduler phase to check if we're in a build
    return WidgetsBinding.instance.schedulerPhase;
  }
}