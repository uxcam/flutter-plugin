import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

// Cache for expensive computations
class _GlobalKeyCache {
  static final Map<GlobalKey, _CachedData> _cache = {};
  static const Duration _cacheExpiry = Duration(milliseconds: 100);
  
  static void invalidate(GlobalKey key) {
    _cache.remove(key);
  }
  
  static void invalidateAll() {
    _cache.clear();
  }
  
  static T? getCached<T>(GlobalKey key, String property) {
    final cached = _cache[key];
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      return cached.data[property] as T?;
    }
    return null;
  }
  
  static void setCached(GlobalKey key, String property, dynamic value) {
    _cache[key] ??= _CachedData(
      timestamp: DateTime.now(),
      data: {},
    );
    _cache[key]!.data[property] = value;
    _cache[key]!.timestamp = DateTime.now();
  }
}

class _CachedData {
  DateTime timestamp;
  Map<String, dynamic> data;
  
  _CachedData({
    required this.timestamp,
    required this.data,
  });
}

extension GlobalKeyExtension on GlobalKey {
  Rect? get globalPaintBounds {
     // Check cache first
    final cachedBounds = _GlobalKeyCache.getCached<Rect>(this, 'globalPaintBounds');
    if (cachedBounds != null) {
      return cachedBounds;
    }

    // Early exit checks to avoid expensive operations
    final context = currentContext;
    if (context == null) return null;

    var visibilityWidget = context.findAncestorWidgetOfExactType<Visibility>();
    if (visibilityWidget != null && !visibilityWidget.visible) {
      _GlobalKeyCache.setCached(this, 'globalPaintBounds', null);
      return null;
    }
    var opacityWidget = context.findAncestorWidgetOfExactType<Opacity>();
    if (opacityWidget != null && opacityWidget.opacity == 0) {
      _GlobalKeyCache.setCached(this, 'globalPaintBounds', null);
      return null;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null || renderObject.paintBounds == null) {
      _GlobalKeyCache.setCached(this, 'globalPaintBounds', null);
      return null;
    }
  
    final translation = renderObject.getTransformTo(null).getTranslation();
     if (translation != null) {
      final offset = Offset(translation.x, translation.y);
      final bounds = renderObject.paintBounds.shift(offset);
      
      // Cache the result
      _GlobalKeyCache.setCached(this, 'globalPaintBounds', bounds);
      return bounds;
    }
    
    return null;
  }

  bool isWidgetVisible() {
    // Check cache first
    final cachedVisibility = _GlobalKeyCache.getCached<bool>(this, 'isVisible');
    if (cachedVisibility != null) {
      return cachedVisibility;
    }
    
    final context = currentContext;
    if (context == null || !context.mounted) {
      _GlobalKeyCache.setCached(this, 'isVisible', false);
      return false;
    }
    
    try {
      ModalRoute? modalRoute = ModalRoute.of(context);
      final isVisible = modalRoute != null &&
          modalRoute.isCurrent &&
          modalRoute.isActive;
      
      _GlobalKeyCache.setCached(this, 'isVisible', isVisible);
      return isVisible;
    } on FlutterError {
      _GlobalKeyCache.setCached(this, 'isVisible', false);
      return false;
    }
  }
}

extension UtilIntExtension on double {
    // Cache device pixel ratio as it doesn't change
  static double? _cachedPixelRatio;
  static bool? _cachedIsAndroid;
  
  static double get _pixelRatio {
    _cachedPixelRatio ??= PlatformDispatcher.instance.views.first.devicePixelRatio;
    return _cachedPixelRatio!;
  }
  
  static bool get _isAndroid {
    _cachedIsAndroid ??= Platform.isAndroid;
    return _cachedIsAndroid!;
  }
  
  int get toNative {
    return (this * (_isAndroid ? _pixelRatio : 1.0)).toInt();
  }

  int get toFlutter {
    return (this / (_isAndroid ? _pixelRatio : 1.0)).toInt();
  }
}

class _ElementCache {
  DateTime timestamp;
  bool isRendered;
  Rect? bounds;
  
  _ElementCache({
    required this.timestamp,
    required this.isRendered,
    this.bounds,
  });
}

extension ElementX on Element {
  // Cache expensive checks
  static final Map<Element, _ElementCache> _elementCache = {};

  void _cacheResult(bool isRendered) {
    _elementCache[this] = _ElementCache(
      timestamp: DateTime.now(),
      isRendered: isRendered,
    );
    
    // Cleanup old cache entries periodically
    if (_elementCache.length > 100) {
      final now = DateTime.now();
      _elementCache.removeWhere((key, value) => 
        now.difference(value.timestamp) > Duration(seconds: 1));
    }
  }

  bool isRendered() {
    // Check cache first
    final cached = _elementCache[this];
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < Duration(milliseconds: 100)) {
      return cached.isRendered;
    }

    final renderObject = this.renderObject;
    if (renderObject == null || renderObject is! RenderBox) {
      _cacheResult(false);
      return false;
    }
    
    if (!renderObject.hasSize) {
      _cacheResult(false);
      return false;
    }

    final visibility = findAncestorWidgetOfExactType<Visibility>();
    if (visibility != null && !visibility.visible) {
      _cacheResult(false);
      return false;
    }
    final offstage = findAncestorWidgetOfExactType<Offstage>();
    if (offstage != null && offstage.offstage) {
      _cacheResult(false);
      return false;
    }
    final opacity = findAncestorWidgetOfExactType<Opacity>();
    if (opacity != null && opacity.opacity == 0.0) {
      _cacheResult(false);
      return false;
    }
    final animatedOpacity = findAncestorWidgetOfExactType<AnimatedOpacity>();
    if (animatedOpacity != null && animatedOpacity.opacity == 0.0) {
      _cacheResult(false);
      return false;
    }

    _cacheResult(true);
    return true;
  }

  bool targetListContainsElement(List<int>? targetList) {
    if (targetList == null || targetList.isEmpty) return false;

    final renderObject = this.renderObject;
    if (renderObject != null && renderObject is RenderBox) {
      return targetList.contains(renderObject.hashCode) ?? false;
    }
    return false;
  }

  String getUniqueId() {
    final slotInParent = this.slot;
    if (slotInParent != null) {
      final slot = (slotInParent as IndexedSlot).index;
      if (slot % 2 == 0) {}
    }
    return "";
  }

  void _cacheBounds(Rect bounds) {
    final existing = _elementCache[this];
    if (existing != null) {
      existing.bounds = bounds;
      existing.timestamp = DateTime.now();
    } else {
      _elementCache[this] = _ElementCache(
        timestamp: DateTime.now(),
        isRendered: bounds != Rect.zero,
        bounds: bounds,
      );
    }
  }

  Rect getEffectiveBounds() {
    final cached = _elementCache[this];
    if (cached != null && 
        cached.bounds != null &&
        DateTime.now().difference(cached.timestamp) < Duration(milliseconds: 100)) {
      return cached.bounds!;
    }
    
    Rect finalBounds = Rect.zero;
    if (this.renderObject is RenderBox) {
      final renderObject = this.renderObject as RenderBox;
      
      if (!renderObject.hasSize) {
        _cacheBounds(Rect.zero);
        return Rect.zero;
      }
      
      final translation = renderObject.getTransformTo(null).getTranslation();
      final offset = Offset(translation.x, translation.y);
      final bounds = renderObject.paintBounds.shift(offset);
      finalBounds = isRendered() ? bounds : Rect.zero;
    }
    
    _cacheBounds(finalBounds);
    return finalBounds;
  }

  Element? getSibling() {
    Element? sibling;
    if (slot is IndexedSlot) {
      final indexInParent = slot as IndexedSlot?;
      int siblingIndex = -1;
      if (indexInParent != null) {
        if (indexInParent.index % 2 == 0) {
          siblingIndex = indexInParent.index + 1;
        } else {
          siblingIndex = indexInParent.index - 1;
        }
      }
      visitAncestorElements((ancestor) {
        ancestor.visitChildren((element) {
          final elementSlot = element.slot;
          if (elementSlot is IndexedSlot && 
              elementSlot.index == siblingIndex) {
            sibling = element;
            return;
          }
        });
        return sibling == null;
      });
    }
    return sibling;
  }
}

extension OptimizedElementX on Element {
  static final Map<int, Rect> _boundsCache = {};
  
  Rect getEffectiveBoundsOptimized() {
    final hashCode = renderObject?.hashCode ?? 0;
    if (hashCode == 0) return Rect.zero;
    
    final cached = _boundsCache[hashCode];
    if (cached != null) return cached;
    
    if (renderObject is RenderBox) {
      final renderBox = renderObject as RenderBox;
      if (!renderBox.hasSize) return Rect.zero;
      
      final translation = renderBox.getTransformTo(null).getTranslation();
      final bounds = renderBox.paintBounds.shift(Offset(translation.x, translation.y));
      
      // Cache with size limit
      if (_boundsCache.length > 100) {
        _boundsCache.clear();
      }
      _boundsCache[hashCode] = bounds;
      return bounds;
    }
    return Rect.zero;
  }
}