import 'package:flutter/widgets.dart';
import 'uxcam_gesture_interceptor.dart';
import 'uxcam_widget_classifier.dart';

class ResolvedHitElement {
  final int hash;
  final Element element;
  final int uxType;

  ResolvedHitElement({
    required this.hash,
    required this.element,
    required this.uxType,
  });
}

class UXCamElementRegistry {
  // Use eager singleton to prevent resurrection issues
  static final UXCamElementRegistry _instance =
      UXCamElementRegistry._internal();
  factory UXCamElementRegistry() => _instance;
  UXCamElementRegistry._internal();

  bool _isInitialized = false;
  final List<WeakReference<Element>> _portals = [];
  // Avoid repeating a full portal search for the same unclassified hit.
  final Set<int> _portalMisses = {};

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void dispose() {
    if (!_isInitialized) return;
    _isInitialized = false;
    _portals.clear();
    _portalMisses.clear();
  }

  List<ResolvedHitElement> resolveHitElements(UXCamHitPath hitPath) {
    final hitHashes = hitPath.hitHashes;
    if (hitHashes.isEmpty) return const [];
    final root = _getRootElement();
    if (root == null) return const [];
    if (_portals.isNotEmpty) {
      _portals.removeWhere((reference) {
        final portal = reference.target;
        return portal == null || !portal.mounted;
      });
    }

    final byHash = <int, ResolvedHitElement>{};

    void visit(Element element) {
      final ro = element.renderObject;
      if (ro is RenderBox) {
        final hash = identityHashCode(ro);
        if (!hitPath.traversable.contains(hash)) return;
        if (hitHashes.contains(hash)) {
          final type = UXCamWidgetClassifier.classifyElement(element);
          if (type != UX_UNKNOWN) {
            byHash[hash] = ResolvedHitElement(
              hash: hash,
              element: element,
              uxType: type,
            );
          }
        }
      }
      element.visitChildElements(visit);
    }

    visit(root);

    // OverlayPortal keeps its overlay child in the Element tree, but attaches
    // its RenderObject directly to the Overlay. A matched render ancestor does
    // not mean the deepest hit was resolved through the Element tree.
    final firstHit = hitHashes.first;
    if (!byHash.containsKey(firstHit)) {
      void visitPortal(Element element) {
        final ro = element.renderObject;
        if (ro is RenderBox &&
            hitPath.traversable.contains(identityHashCode(ro))) {
          visit(element);
          return;
        }
        element.visitChildElements((child) {
          final childRo = child.renderObject;
          if (identical(childRo, ro)) {
            visitPortal(child);
          } else if (childRo is RenderBox &&
              hitPath.traversable.contains(identityHashCode(childRo))) {
            visit(child);
          }
        });
      }

      void tryPortals() {
        for (final reference in _portals) {
          final portal = reference.target;
          if (portal != null && portal.mounted) visitPortal(portal);
        }
      }

      final matchCount = byHash.length;
      tryPortals();

      void findPortals(Element element) {
        if (element.widget is OverlayPortal) {
          _portals.add(WeakReference(element));
        }
        element.visitChildElements(findPortals);
      }

      if (byHash.length == matchCount && !_portalMisses.contains(firstHit)) {
        _portals.clear();
        findPortals(root);
        tryPortals();
        if (byHash.length == matchCount) {
          if (_portalMisses.length >= 256) _portalMisses.clear();
          _portalMisses.add(firstHit);
        }
      }
    }

    final ordered = <ResolvedHitElement>[];
    for (final hash in hitHashes) {
      final resolved = byHash[hash];
      if (resolved != null) ordered.add(resolved);
    }
    return ordered;
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

  void onRouteChange() {
    _portals.clear();
    _portalMisses.clear();
  }

  void onAppResumed() => _portalMisses.clear();

  void markDirty() {}

  void handleMemoryPressure() {
    _portals.clear();
    _portalMisses.clear();
  }

  int get cacheSize => 0;

  bool get isInitialized => _isInitialized;
}
