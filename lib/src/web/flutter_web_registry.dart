import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Injects the Flutter semantics tree as DOM elements behind
/// the Flutter canvas so the UXCam Web SDK captures them
/// via its MutationObserver.
class FlutterWebRegistry {
  FlutterWebRegistry._();

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  Timer? _debounce;
  Map<int, String> _lastSentMap = {};
  bool _isListening = false;

    void start() {
    if (_isListening) return;
    _isListening = true;

    // Poll until semantics owner is available, then attach listener
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      for (final renderView in RendererBinding.instance.renderViews) {
        final owner = renderView.owner?.semanticsOwner;
        if (owner == null) continue;

        owner.addListener(_onSemanticsChanged);
        timer.cancel();

        // Do initial scan
        _scheduleCollect();
        return;
      }
    });
  }

  void _onSemanticsChanged() {
    _scheduleCollect();
  }

    /// Debounce: wait 200ms after last change before walking trees
  void _scheduleCollect() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _collectAndPush);
  }

  void _collectAndPush() {
    // Step 1: Walk semantics tree → collect {nodeId: globalRect}
    final semanticsRects = <int, Rect>{};
    for (final renderView in RendererBinding.instance.renderViews) {
      final owner = renderView.owner?.semanticsOwner;
      if (owner == null) continue;
      final root = owner.rootSemanticsNode;
      if (root == null) continue;
      _collectSemanticsRects(root, Matrix4.identity(), semanticsRects);
    }

    // Step 2: Walk element tree → collect {globalRect: imageUrl}
    final imageRects = <Rect, String>{};
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement != null) {
      _collectImageRects(rootElement, imageRects);
    }

    // Step 3: Match by rect overlap → build {nodeId: imageUrl}
    // For each image, find the SMALLEST semantic node that overlaps it.
    // This avoids matching parent containers (root, scaffold, etc.)
    final dpr = web.window.devicePixelRatio;
    final imageMap = <int, String>{};

    // Pre-convert semantics rects to logical pixels
    final logicalSemRects = <int, Rect>{};
    for (final semEntry in semanticsRects.entries) {
      logicalSemRects[semEntry.key] = Rect.fromLTWH(
        semEntry.value.left / dpr,
        semEntry.value.top / dpr,
        semEntry.value.width / dpr,
        semEntry.value.height / dpr,
      );
    }

    for (final imgEntry in imageRects.entries) {
      final imgRect = imgEntry.key;
      final imgUrl = imgEntry.value;

      int? bestNodeId;
      double bestArea = double.infinity;

      for (final semEntry in logicalSemRects.entries) {
        if (_rectsOverlap(semEntry.value, imgRect)) {
          final area = semEntry.value.width * semEntry.value.height;
          if (area < bestArea) {
            bestArea = area;
            bestNodeId = semEntry.key;
          }
        }
      }

      if (bestNodeId != null) {
        imageMap[bestNodeId] = imgUrl;
      }
    }


    // Step 4: Diff against last sent — only push if changed
    if (!_mapsEqual(imageMap, _lastSentMap)) {
      _lastSentMap = Map.from(imageMap);
      _pushToJs(imageMap);
    }
  }

  /// Walk semantics tree, accumulate transforms, store {nodeId: globalRect}
  void _collectSemanticsRects(
    SemanticsNode node,
    Matrix4 parentTransform,
    Map<int, Rect> out,
  ) {
    final transform = node.transform != null
        ? parentTransform.multiplied(node.transform!)
        : parentTransform;

    final globalRect = MatrixUtils.transformRect(transform, node.rect);
    out[node.id] = globalRect;

    node.visitChildren((child) {
      _collectSemanticsRects(child, transform, out);
      return true;
    });
  }

  /// Walk element tree, find Image widgets, store {globalRect: imageUrl}
  void _collectImageRects(Element element, Map<Rect, String> out) {
    final widget = element.widget;

    if (widget is Image) {
      final url = _extractImageUrl(widget);
      if (url != null) {
        final ro = element.renderObject;
        if (ro is RenderBox && ro.hasSize) {
          final translation = ro.getTransformTo(null).getTranslation();
          final rect = ro.paintBounds.shift(
            Offset(translation.x, translation.y),
          );
          out[rect] = url;
        }
      }
    }

    element.visitChildElements((child) {
      _collectImageRects(child, out);
    });
  }

  /// Extract URL from Image widget's ImageProvider
  String? _extractImageUrl(Image widget) {
    final provider = widget.image;
    if (provider is AssetImage) return provider.assetName;
    if (provider is ExactAssetImage) return provider.assetName;
    if (provider is NetworkImage) return provider.url;

    // Fallback: parse from toString()
    final str = provider.toString();
    final regex = RegExp(r'"([^"]+)"');
    final match = regex.firstMatch(str);
    if (match != null && match.group(1) != 'null') {
      return match.group(1);
    }
    return null;
  }

  /// Check if two rects overlap significantly
  bool _rectsOverlap(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.isEmpty) return false;
    final overlapArea = intersection.width * intersection.height;
    final smallerArea =
        (a.width * a.height) < (b.width * b.height)
            ? a.width * a.height
            : b.width * b.height;
    // Image rect should be at least 30% inside the semantics rect
    return smallerArea > 0 && overlapArea / smallerArea > 0.3;
  }

  bool _mapsEqual(Map<int, String> a, Map<int, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  /// Push the map to JS as window.__uxcamImageMap
  void _pushToJs(Map<int, String> imageMap) {
    final jsonStr = jsonEncode(
      imageMap.map((k, v) => MapEntry(k.toString(), v)),
    );
    print("scan result:" + imageMap.toString());
    _evalJs('''
      window.__uxcamImageMap = $jsonStr;
      window.dispatchEvent(new CustomEvent('uxcam-image-update'));
    '''.toJS);
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _lastSentMap.clear();
    _isListening = false;
  }
}

@JS('eval')
external void _evalJs(JSString code);