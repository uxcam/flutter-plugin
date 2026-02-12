import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Injects the Flutter semantics tree as DOM elements behind
/// the Flutter canvas so the UXCam Web SDK captures them
/// via its MutationObserver.
class FlutterWebRegistry with WidgetsBindingObserver {
  FlutterWebRegistry._() {
    WidgetsBinding.instance.addObserver(this);
    _waitForFirstFrame();
  }

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  Timer? _scanTimer;
  web.HTMLElement? _semanticsContainer;

  /// Wait for the semantic tree to be ready, then inject once.
  void _waitForFirstFrame() {
    _scanTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _onTick();
    });
  }

  void dispose() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _semanticsContainer?.remove();
    _semanticsContainer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _onTick() {

    for (final renderView in RendererBinding.instance.renderViews) {
      final owner = renderView.owner?.semanticsOwner;
      if (owner == null) continue;

      final root = owner.rootSemanticsNode;
      if (root == null) continue;

      // Check the tree has actual content (more than just root)
      if (!root.hasChildren) continue;

      _injectSemanticsDom(root);

      // Stop the timer — we only needed one snapshot
      _scanTimer?.cancel();
      _scanTimer = null;
    }
  }

  void _injectSemanticsDom(SemanticsNode root) {
    _semanticsContainer?.remove();

    final container = web.document.createElement('div') as web.HTMLElement;
    container.id = 'uxcam-flutter-semantics';
    container.style.setProperty('position', 'absolute');
    container.style.setProperty('top', '0');
    container.style.setProperty('left', '0');
    container.style.setProperty('width', '100%');
    container.style.setProperty('height', '100%');
    container.style.setProperty('pointer-events', 'none');
    container.style.setProperty('overflow', 'hidden');
    container.style.setProperty('z-index', '-1');

    _buildDomNode(root, container, Matrix4.identity());

    web.document.body?.appendChild(container);
    _semanticsContainer = container;
  }

  void _buildDomNode(
      SemanticsNode node, web.HTMLElement parent, Matrix4 parentTransform) {
    final Matrix4 accumulatedTransform = node.transform != null
        ? parentTransform.multiplied(node.transform!)
        : parentTransform;

    final globalRect =
        MatrixUtils.transformRect(accumulatedTransform, node.rect);

    // Convert from physical pixels to CSS (logical) pixels.
    final dpr = web.window.devicePixelRatio;
    final cssLeft   = globalRect.left   / dpr;
    final cssTop    = globalRect.top    / dpr;
    final cssWidth  = globalRect.width  / dpr;
    final cssHeight = globalRect.height / dpr;

    final tag = node.hasChildren ? 'div' : 'span';
    final el = web.document.createElement(tag) as web.HTMLElement;

    el.setAttribute('data-sem-id', 'sem_${node.id}');
    el.style.setProperty('position', 'absolute');
    el.style.setProperty('left', '${cssLeft.toStringAsFixed(1)}px');
    el.style.setProperty('top', '${cssTop.toStringAsFixed(1)}px');
    el.style.setProperty('width', '${cssWidth.toStringAsFixed(1)}px');
    el.style.setProperty('height', '${cssHeight.toStringAsFixed(1)}px');

    if (node.label.isNotEmpty) {
      el.setAttribute('data-label', node.label);
      if (!node.hasChildren) {
        el.textContent = node.label;
      }
    }

    parent.appendChild(el);

    node.visitChildren((child) {
      _buildDomNode(child, el, accumulatedTransform);
      return true;
    });
  }
}
