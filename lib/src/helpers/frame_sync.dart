import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';

/// Alternative approach to frame synchronization using RepaintBoundary
/// This avoids frame deferral while maintaining perfect synchronization
/// between occlusion rects and screenshots

class FrameSyncManager {
  static final FrameSyncManager _instance = FrameSyncManager._internal();
  factory FrameSyncManager() => _instance;
  FrameSyncManager._internal();
  
  // Global RepaintBoundary key for capturing frames
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  
  // Frame buffer for double-buffering approach
  _CapturedFrame? _currentFrame;
  _CapturedFrame? _previousFrame;
  
  // Synchronization lock
  bool _isCapturing = false;
  Completer<_CapturedFrame>? _captureCompleter;
  
  GlobalKey get repaintBoundaryKey => _repaintBoundaryKey;
  
  /// Capture current frame with occlusion rects atomically
  Future<Map<String, dynamic>> captureFrameWithOcclusion() async {
    // Prevent concurrent captures
    if (_isCapturing) {
      if (_captureCompleter != null) {
        final frame = await _captureCompleter!.future;
        return frame.toMap();
      }
    }
    
    _isCapturing = true;
    _captureCompleter = Completer<_CapturedFrame>();
    
    try {
      // Step 1: Wait for stable render state
      await _waitForRenderStable();
      
      // Step 2: Capture occlusion rects and frame image atomically
      final capturedFrame = await _captureAtomically();
      
      // Step 3: Update frame buffer
      _previousFrame = _currentFrame;
      _currentFrame = capturedFrame;
      
      _captureCompleter!.complete(capturedFrame);
      return capturedFrame.toMap();
      
    } catch (e) {
      print('Error capturing frame: $e');
      final errorFrame = _CapturedFrame.error(e.toString());
      _captureCompleter!.completeError(e);
      return errorFrame.toMap();
    } finally {
      _isCapturing = false;
      _captureCompleter = null;
    }
  }
  
  Future<_CapturedFrame> _captureAtomically() async {
    final timestamp = DateTime.now();
    final frameId = timestamp.millisecondsSinceEpoch;
    
    // Use microtask to ensure atomic execution
    return await Future.microtask(() async {
      // Capture occlusion rects
      final occlusionRects = OcclusionWrapperManager().fetchOcclusionRects();
      
      // Capture frame image if RepaintBoundary is available
      Uint8List? frameBytes;
      ui.Image? image;
      
      if (_repaintBoundaryKey.currentContext != null) {
        final boundary = _repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
        
        if (boundary != null) {
          try {
            // Capture at device pixel ratio for accuracy
            image = await boundary.toImage(
              pixelRatio: ui.window.devicePixelRatio,
            );
            
            // Convert to PNG bytes
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            frameBytes = byteData?.buffer.asUint8List();
          } catch (e) {
            print('Failed to capture frame image: $e');
          } finally {
            image?.dispose();
          }
        }
      }
      
      return _CapturedFrame(
        frameId: frameId,
        timestamp: timestamp,
        occlusionRects: occlusionRects,
        frameBytes: frameBytes,
      );
    });
  }
  
  Future<void> _waitForRenderStable() async {
    final binding = WidgetsBinding.instance;
    
    // Wait for any pending frames to complete
    if (binding.hasScheduledFrame) {
      await binding.endOfFrame;
    }
    
    // Additional synchronization point
    await Future.delayed(Duration.zero);
  }
  
  /// Get the most recent captured frame
  _CapturedFrame? get currentFrame => _currentFrame;
  
  /// Get the previous captured frame (for comparison/validation)
  _CapturedFrame? get previousFrame => _previousFrame;
}

class _CapturedFrame {
  final int frameId;
  final DateTime timestamp;
  final List<Map<String, dynamic>> occlusionRects;
  final Uint8List? frameBytes;
  final String? error;
  
  _CapturedFrame({
    required this.frameId,
    required this.timestamp,
    required this.occlusionRects,
    this.frameBytes,
    this.error,
  });
  
  factory _CapturedFrame.error(String error) {
    return _CapturedFrame(
      frameId: 0,
      timestamp: DateTime.now(),
      occlusionRects: [],
      error: error,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'frameId': frameId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'occlusionRects': occlusionRects,
      'frameBytes': frameBytes,
      'hasCapturedImage': frameBytes != null,
      'error': error,
    };
  }
}

/// Modified app wrapper that includes RepaintBoundary at root level
class UXCamAppWrapper extends StatelessWidget {
  final Widget child;
  
  const UXCamAppWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: FrameSyncManager().repaintBoundaryKey,
      child: child,
    );
  }
}

/// Optimized Channel Callback using frame capture approach
class OptimizedChannelCallback {
  static final FrameSyncManager _frameSyncManager = FrameSyncManager();
  static bool _isProcessing = false;
  
  static Future<void> handleChannelCallBacks(MethodChannel channel) async {
    channel.setMethodCallHandler((MethodCall call) async {
      try {
        switch (call.method) {
          case 'captureFrameWithOcclusion':
            // New unified approach - no frame deferral needed
            return await _handleCaptureFrame();
            
          case 'pauseRendering':
            // Legacy support with optimization
            return await _handlePauseWithCapture();
            
          case 'requestAllOcclusionRects':
            // Return cached frame data
            return _frameSyncManager.currentFrame?.occlusionRects ?? [];
            
          default:
            return null;
        }
      } catch (e) {
        print('Channel callback error: $e');
        return null;
      }
    });
  }
  
  static Future<Map<String, dynamic>> _handleCaptureFrame() async {
    if (_isProcessing) {
      // Return cached frame if processing
      return _frameSyncManager.currentFrame?.toMap() ?? {};
    }
    
    _isProcessing = true;
    try {
      // Capture frame with perfect synchronization
      final frameData = await _frameSyncManager.captureFrameWithOcclusion();
      return frameData;
    } finally {
      _isProcessing = false;
    }
  }
  
  static Future<bool> _handlePauseWithCapture() async {
    // Instead of deferring frames, capture current state
    try {
      final frameData = await _frameSyncManager.captureFrameWithOcclusion();
      // Native side can now use the captured frame data
      return frameData['error'] == null;
    } catch (e) {
      return false;
    }
  }
}

/// Usage Example:
/// 
/// void main() {
///   runApp(
///     UXCamAppWrapper(
///       child: MaterialApp(
///         home: MyApp(),
///       ),
///     ),
///   );
/// }
/// 
/// Benefits:
/// 1. No frame deferral needed - better performance
/// 2. Perfect synchronization - rects and image captured atomically
/// 3. Optional frame capture - can work with or without image
/// 4. Double buffering - can compare frames for validation
/// 5. Non-blocking - uses async capture instead of pausing