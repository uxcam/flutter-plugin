import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'uxcam_widget_classifier.dart';

class CachedElementInfo {
  final int uxType;
  final String widgetType;
  Rect? _bounds;

  CachedElementInfo({
    required this.uxType,
    required this.widgetType,
  });

  Rect? get bounds => _bounds;
  set bounds(Rect? value) => _bounds = value;
}

abstract class _ElementRefStorage {
  Element? get(int hash);
  void set(int hash, Element element);
  void remove(int hash);
  void clear();
  int get length;
}

class _WeakRefElementRefStorage implements _ElementRefStorage {
  final Map<int, WeakReference<Element>> _refs = {};

  @override
  Element? get(int hash) {
    final ref = _refs[hash];
    if (ref == null) return null;
    final target = ref.target;
    if (target == null) {
      _refs.remove(hash); // Clean up dead reference on access
      return null;
    }
    return target;
  }

  @override
  void set(int hash, Element element) {
    _refs[hash] = WeakReference(element);
  }

  @override
  void remove(int hash) => _refs.remove(hash);

  @override
  void clear() => _refs.clear();

  @override
  int get length => _refs.length;

  /// Clean up entries where WeakReference target has been GC'd
  void cleanupDead() {
    _refs.removeWhere((_, ref) => ref.target == null);
  }
}

class _ExpandoElementRefStorage implements _ElementRefStorage {
  final Map<int, Element> _hashToElement = {};

  @override
  Element? get(int hash) {
    final element = _hashToElement[hash];
    if (element != null && !element.mounted) {
      _hashToElement.remove(hash);
      return null;
    }
    return element;
  }

  @override
  void set(int hash, Element element) {
    _hashToElement[hash] = element;
  }

  @override
  void remove(int hash) {
    _hashToElement.remove(hash);
  }

  @override
  void clear() => _hashToElement.clear();

  @override
  int get length => _hashToElement.length;

  /// Clean up entries where Element is no longer mounted
  void cleanupUnmounted() {
    _hashToElement.removeWhere((_, element) => !element.mounted);
  }
}

/// Frame-synchronized element caching and indexing.
class UXCamElementRegistry {
  // Use eager singleton to prevent resurrection issues
  static final UXCamElementRegistry _instance = UXCamElementRegistry._internal();
  factory UXCamElementRegistry() => _instance;
  UXCamElementRegistry._internal();

  late _ElementRefStorage _elementRefs;
  final Map<int, CachedElementInfo> _cache = {};
  final Map<int, String> _routeCache = {};

  bool _isInitialized = false;
  bool _treeDirty = true;

  static const _maxCacheSize = 5000;
  static const _prunedCacheSize = 3000;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _elementRefs = _createElementRefStorage();
  }

  void dispose() {
    if (!_isInitialized) return;

    _isInitialized = false;

    _elementRefs.clear();
    _cache.clear();
    _routeCache.clear();
  }

  _ElementRefStorage _createElementRefStorage() {
    if (kIsWeb) return _ExpandoElementRefStorage();
    try {
      WeakReference<Object>(Object());
      return _WeakRefElementRefStorage();
    } catch (_) {
      return _ExpandoElementRefStorage();
    }
  }

  void ensureFreshForTap(Set<int> hitTargetHashes) {
    // Rebuild if tree is dirty (route change, app resume)
    if (_treeDirty) {
      _rebuildCacheSync();
      return;
    }

    // Rebuild if any hit targets are missing from cache
    final missingTargets = hitTargetHashes.where((h) => !_cache.containsKey(h));
    if (missingTargets.isNotEmpty) {
      _rebuildCacheSync();
      return;
    }

    // Rebuild if any cached elements are no longer mounted
    for (final hash in hitTargetHashes) {
      final element = _elementRefs.get(hash);
      if (element == null || !element.mounted) {
        _rebuildCacheSync();
        return;
      }
    }
  }

  void _rebuildCacheSync() {
    _treeDirty = false;

    // Clean up dead references from storage first
    if (_elementRefs is _WeakRefElementRefStorage) {
      (_elementRefs as _WeakRefElementRefStorage).cleanupDead();
    } else if (_elementRefs is _ExpandoElementRefStorage) {
      (_elementRefs as _ExpandoElementRefStorage).cleanupUnmounted();
    }

    _cleanupDeadReferences();

    final rootElement = _getRootElement();
    if (rootElement == null) {
      _treeDirty = true;
      return;
    }

    _visitElementsSelectively(rootElement);

    if (_cache.length > _maxCacheSize) {
      _pruneOldestEntries(targetSize: _prunedCacheSize);
    }
  }

  Element? _getRootElement() {
    try {
      // Use rootElement (modern API) with fallback to deprecated renderViewElement
      // for backward compatibility with older Flutter versions
      final binding = WidgetsBinding.instance;
      try {
        return binding.rootElement;
      } catch (_) {
        // Fallback for older Flutter versions
        // ignore: deprecated_member_use
        return binding.renderViewElement;
      }
    } catch (_) {
      return null;
    }
  }

  void _cleanupDeadReferences() {
    final deadKeys = <int>[];
    for (final entry in _cache.entries) {
      final element = _elementRefs.get(entry.key);
      if (element == null || !element.mounted) {
        deadKeys.add(entry.key);
      }
    }
    for (final key in deadKeys) {
      _elementRefs.remove(key);
      _cache.remove(key);
    }
  }

  void _visitElementsSelectively(Element element) {
    final ro = element.renderObject;
    if (ro != null) {
      final type = UXCamWidgetClassifier.classifyElement(element);
      if (type != UX_UNKNOWN) {
        final hash = identityHashCode(ro);
        _cacheElement(element, hash, type);
      }
    }

    element.visitChildElements(_visitElementsSelectively);
  }

  void _cacheElement(Element element, int hash, int uxType) {
    _elementRefs.set(hash, element);
    _cache[hash] = CachedElementInfo(
      uxType: uxType,
      widgetType:
          UXCamWidgetClassifier.getDisplayName(element.widget.runtimeType),
    );
  }

  Element? getElement(int hash) {
    final element = _elementRefs.get(hash);
    if (element == null || !element.mounted) {
      _elementRefs.remove(hash);
      _cache.remove(hash);
      return null;
    }
    return element;
  }

  CachedElementInfo? getCachedInfo(int hash) => _cache[hash];

  List<MapEntry<int, Element>> getMatchingElements(Set<int> hitTargets) {
    final results = <MapEntry<int, Element>>[];
    for (final hash in hitTargets) {
      final element = getElement(hash);
      if (element != null) {
        results.add(MapEntry(hash, element));
      }
    }
    return results;
  }

  void _pruneOldestEntries({required int targetSize}) {
    final keysToRemove = _cache.keys.take(_cache.length - targetSize).toList();
    for (final key in keysToRemove) {
      _elementRefs.remove(key);
      _cache.remove(key);
    }
  }

  void onRouteChange() {
    _routeCache.clear();
    _cache.clear();
    _elementRefs.clear();
    _treeDirty = true;
  }

  void onAppResumed() {
    _treeDirty = true;
  }

  void markDirty() {
    _treeDirty = true;
  }

  void handleMemoryPressure() {
    if (_cache.length > 1000) {
      _pruneOldestEntries(targetSize: 500);
    }
  }

  int get cacheSize => _cache.length;

  bool get isInitialized => _isInitialized;
}
