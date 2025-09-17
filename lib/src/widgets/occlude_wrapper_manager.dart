import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class OcclusionWrapperItem {
  final UniqueKey id;
  final GlobalKey key;

  OcclusionWrapperItem({required this.id, required this.key});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OcclusionWrapperItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class OcclusionWrapperManager {
  OcclusionWrapperManager._privateConstructor();

  static final OcclusionWrapperManager _instance =
      OcclusionWrapperManager._privateConstructor();

  factory OcclusionWrapperManager() => _instance;

  final items = <OcclusionWrapperItem>[];

  final occlusionRects = <UniqueKey, OccludePoint>{};
  final rects = <GlobalKey, OccludePoint>{};
  
  Timer? _updateTimer;
  Duration _currentUpdateInterval = const Duration(milliseconds: 100);
  
  // Track native call frequency for dynamic timer adjustment
  final List<DateTime> _nativeCallTimestamps = [];
  static const int _maxCallHistory = 5;
  static const Duration _minInterval = Duration(milliseconds: 100); // ~10fps
  static const Duration _maxInterval = Duration(milliseconds: 1000); // ~fps
  static const Duration _defaultInterval = Duration(milliseconds: 100); // ~10fps

  void add(int timeStamp, GlobalKey key, Rect rect) {
    rects.remove(key);
    rects[key] = OccludePoint(
      rect.left.toNative,
      rect.top.toNative,
      rect.right.toNative,
      rect.bottom.toNative,
    );
    // Timer is managed by registration/unregistration lifecycle
  }
  
  void _startUpdateTimerIfNeeded() {
    if (_updateTimer == null && items.isNotEmpty) {
      _updateTimer = Timer.periodic(_currentUpdateInterval, (_) {
        _sendRectsToNative();
      });
    }
  }
  
  void _restartTimerWithNewInterval() {
    if (_updateTimer != null && items.isNotEmpty) {
      _stopUpdateTimer();
      _startUpdateTimerIfNeeded();
    }
  }
  
  void _stopUpdateTimer() {
    _nativeCallTimestamps.clear();
    _updateTimer?.cancel();
    _updateTimer = null;
  }
  
  void _sendRectsToNative() {
    if (rects.isEmpty) {
      _stopUpdateTimer();
      return;
    }
    
    // Clean up rects for keys that are no longer registered
    _cleanupUnregisteredRects();
    
    if (rects.isEmpty) {
      _stopUpdateTimer();
      return;
    }
    
    List<Map<String, dynamic>> rectList = [];
    rects.forEach((key, value) {
      if (key.isWidgetVisible()) {
        Map<String, dynamic> rectData = {
          "key": key.toString(),
          "point": value.toJson(),
          "isVisible": true,
        };
        rectList.add(rectData);
      }
    });
    
    // Always send to native since native doesn't cache/store the data
    // Native side needs fresh data every time for proper occlusion tracking
    if (Platform.isAndroid && rectList.isNotEmpty) {
      FlutterUxcam.addFrameData(DateTime.now().millisecondsSinceEpoch, jsonEncode(rectList));
    }
  }
  
  void _cleanupUnregisteredRects() {
    final registeredKeys = items.map((item) => item.key).toSet();
    rects.removeWhere((key, _) => !registeredKeys.contains(key));
  }

  void clearOcclusionRects() {
    occlusionRects.clear();
  }

  bool containsWidgetByKey(GlobalKey key) {
    return items.any((item) {
      return item.key == key;
    });
  }

  /// Register Flutter Widget for occlusion
  /// Uses weak reference approach - only stores item if not already present
  void registerOcclusionWrapper(OcclusionWrapperItem item) {
    if (!items.contains(item)) {
      items.add(item);
      // Start timer when first widget is registered
      _startUpdateTimerIfNeeded();
    }
  }

  /// UnRegister Occlusion Wrapper Widget for removing occlusion rect
  void unRegisterOcclusionWrapper(UniqueKey id) {
    if (items.isNotEmpty) {
      // Find the wrapper to get its key before removing
      final wrapperToRemove = items.where((wrapper) => wrapper.id == id).firstOrNull;
      
      items.removeWhere((wrapper) => wrapper.id == id);
      
      // Remove the corresponding rect entry
      if (wrapperToRemove != null) {
        rects.remove(wrapperToRemove.key);
      }
      
      if (occlusionRects.containsKey(id)) {
        occlusionRects.removeWhere((key, _) => key == id);
      }
      
      // Stop timer if no more items
      if (items.isEmpty) {
        _stopUpdateTimer();
      }
    }
  }

  List<OcclusionWrapperItem> getWrappers() => List.unmodifiable(items);

  List<Map<String, dynamic>> fetchOcclusionRects() {
    var occlusionPoints = getOccludePoints();
    var json = occlusionPoints.map((rect) => rect.toJson()).toList();
    return json;
  }

  List<OccludePoint> getOccludePoints() {
    // Track this call from native to measure frequency
    _recordNativeCall();
    return items.map((wrapper) => getOccludePoint(wrapper.key)).toList();
  }
  
  void _recordNativeCall() {
    // don't record if we have too many calls
    if (_nativeCallTimestamps.length >= _maxCallHistory) {
      return;
    }
    final now = DateTime.now();
    _nativeCallTimestamps.add(now);
    
    // Adjust timer interval based on native call frequency
    _adjustTimerInterval();
  }
  
  void _adjustTimerInterval() {
    if (_nativeCallTimestamps.length < 2) return; // Need some history
    
    // Calculate average interval between native calls
    final recentCalls = _nativeCallTimestamps.take(_maxCallHistory).toList();
    if (recentCalls.length < 2) return;
    
    Duration totalDuration = Duration.zero;
    for (int i = 1; i < recentCalls.length; i++) {
      totalDuration += recentCalls[i].difference(recentCalls[i - 1]);
    }
    
    final averageNativeInterval = Duration(
      milliseconds: totalDuration.inMilliseconds ~/ (recentCalls.length - 1)
    );
    
    final targetInterval = Duration(
      milliseconds: (averageNativeInterval.inMilliseconds).round()
    );
    
    // Clamp to reasonable bounds
    final clampedInterval = Duration(
      milliseconds: targetInterval.inMilliseconds.clamp(
        _minInterval.inMilliseconds,
        _maxInterval.inMilliseconds
      )
    );
    
    // Only restart timer if interval changed significantly (>10ms difference)
    if ((clampedInterval.inMilliseconds - _currentUpdateInterval.inMilliseconds).abs() > 10) {
      _currentUpdateInterval = clampedInterval;
      _restartTimerWithNewInterval();
      

    }
  }
  
  /// Reset timer interval to default (useful for testing or manual reset)
  void resetTimerInterval() {
    _nativeCallTimestamps.clear();
    _currentUpdateInterval = _defaultInterval;
    _restartTimerWithNewInterval();
  }
  
  /// Get current timer interval (for debugging/monitoring)
  Duration get currentTimerInterval => _currentUpdateInterval;

  OccludePoint getOccludePoint(GlobalKey<State<StatefulWidget>> key) {
    var occludePoint = OccludePoint(0, 0, 0, 0);

    Rect? bound = key.globalPaintBounds;

    if (bound == null) return occludePoint;

    occludePoint = OccludePoint(
      bound.left.toNative,
      bound.top.toNative,
      bound.right.toNative,
      bound.bottom.toNative,
    );

    return occludePoint;
  }
}
