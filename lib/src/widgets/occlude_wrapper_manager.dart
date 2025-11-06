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

  // Track native call frequency for dynamic timer adjustment
  static const int _maxRectsSize = 500; // Prevent unbounded growth
  static const int _maxItemsSize = 500; // Prevent unbounded growth
  
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

    _sendRectsToNative();
  }
  void _sendRectsToNative() {
    if (rects.isEmpty) {
      _cachedJsonData = null;
      _lastRectsHash = 0;
      FlutterUxcam.addFrameData(DateTime.now().millisecondsSinceEpoch, "");
      return;
    }
    
    // Clean up rects for keys that are no longer registered
    _cleanupUnregisteredRects();
    
    if (rects.isEmpty) {
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
    return items.map((wrapper) => getOccludePoint(wrapper.key)).toList();
  }

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
    items.clear();
    rects.clear();
    occlusionRects.clear();
    _cachedJsonData = null;
    _lastRectsHash = 0;
  }
}
