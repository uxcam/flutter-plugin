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
  static const int _maxRectsSize = 500; // Prevent unbounded growth
  static const int _maxItemsSize = 500; // Prevent unbounded growth
  static const Duration _minInterval = Duration(milliseconds: 100); // ~10fps
  static const Duration _maxInterval = Duration(milliseconds: 1000); // ~1fps
  static const Duration _defaultInterval = Duration(milliseconds: 100); // ~10fps
  
  // Cache for JSON encoding to reduce repeated string allocations
  String? _cachedJsonData;
  int _lastRectsHash = 0;

  void add(int timeStamp, GlobalKey key, Rect rect) {
    rects.remove(key);
    rects[key] = OccludePoint(
      rect.left.toNative,
      rect.top.toNative,
      rect.right.toNative,
      rect.bottom.toNative,
    );
    
    // Prevent unbounded growth - remove oldest entries if limit exceeded
    if (rects.length > _maxRectsSize) {
      final keysToRemove = rects.keys.take(rects.length - _maxRectsSize).toList();
      for (final key in keysToRemove) {
        rects.remove(key);
      }
      // Invalidate cache when rects are removed
      _cachedJsonData = null;
      _lastRectsHash = 0;
    }
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
      _cachedJsonData = null;
      _lastRectsHash = 0;
      return;
    }
    
    // Clean up rects for keys that are no longer registered
    _cleanupUnregisteredRects();
    
    if (rects.isEmpty) {
      _stopUpdateTimer();
      _cachedJsonData = null;
      _lastRectsHash = 0;
      return;
    }
    
    // Calculate a simple hash of the rects to detect changes
    int currentHash = 0;
    List<Map<String, dynamic>>? rectList;
    
    rects.forEach((key, value) {
      // Simple hash based on key and value
      currentHash = currentHash ^ key.hashCode ^ value.hashCode;
    });
    
    // Only rebuild rectList and re-encode JSON if data changed
    if (_cachedJsonData == null || currentHash != _lastRectsHash) {
      rectList = [];
      rects.forEach((key, value) {
        if (key.isWidgetVisible()) {
          Map<String, dynamic> rectData = {
            "key": key.toString(),
            "point": value.toJson(),
            "isVisible": true,
          };
          rectList!.add(rectData);
        }
      });
      
      if (rectList.isNotEmpty) {
        _cachedJsonData = jsonEncode(rectList);
        _lastRectsHash = currentHash;
      } else {
        _cachedJsonData = null;
        _lastRectsHash = 0;
      }
    }
    
    // Always send to native since native doesn't cache/store the data
    // Native side needs fresh data every time for proper occlusion tracking
    // But reuse cached JSON string to avoid repeated encoding
    if (Platform.isAndroid && _cachedJsonData != null) {
      FlutterUxcam.addFrameData(DateTime.now().millisecondsSinceEpoch, _cachedJsonData!);
    }
  }
  
  void _cleanupUnregisteredRects() {
    final registeredKeys = items.map((item) => item.key).toSet();
    rects.removeWhere((key, _) => !registeredKeys.contains(key));
  }

  void clearOcclusionRects() {
    occlusionRects.clear();
    // Invalidate cache when clearing
    _cachedJsonData = null;
    _lastRectsHash = 0;
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
      
      // Prevent unbounded growth - remove oldest entries if limit exceeded
      if (items.length > _maxItemsSize) {
        final itemsToRemove = items.take(items.length - _maxItemsSize).toList();
        for (final item in itemsToRemove) {
          items.remove(item);
          rects.remove(item.key);
          occlusionRects.remove(item.id);
        }
      }
      
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
  bool hasOcclusionRects() {
    var occlusionPoints = getOccludePoints();
    bool check = occlusionPoints.length > 0;
    return check;
  }

  List<OccludePoint> getOccludePoints() {
    // Track this call from native to measure frequency
    _recordNativeCall();
    return items.map((wrapper) => getOccludePoint(wrapper.key)).toList();
  }
  
  void _recordNativeCall() {
    final now = DateTime.now();
    _nativeCallTimestamps.add(now);
    
    // Keep only recent history to prevent memory leak
    if (_nativeCallTimestamps.length > _maxCallHistory) {
      _nativeCallTimestamps.removeRange(0, _nativeCallTimestamps.length - _maxCallHistory);
    }
    
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
  
  /// Dispose and cleanup all resources to prevent memory leaks
  void dispose() {
    _stopUpdateTimer();
    items.clear();
    rects.clear();
    occlusionRects.clear();
    _nativeCallTimestamps.clear();
    _cachedJsonData = null;
    _lastRectsHash = 0;
  }
}
