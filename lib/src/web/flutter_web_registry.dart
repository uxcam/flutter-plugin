import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Periodically scans the Flutter semantics tree on every frame
/// and serializes it into the INode format (non-minified).
class FlutterWebRegistry with WidgetsBindingObserver {
  FlutterWebRegistry._() {
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicScan();
  }

  Timer? _scanTimer;

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  void _startPeriodicScan({Duration interval = const Duration(milliseconds: 200)}) {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(interval, (_) {
      _scheduleScan();
    });
  }

  void _scheduleScan() {
    for (final renderView in RendererBinding.instance.renderViews) {
      final owner = renderView.owner?.semanticsOwner;
      if (owner == null) continue;

      final root = owner.rootSemanticsNode;
      if (root == null) continue;

      final iNode = _semanticsNodeToINode(root, Matrix4.identity());
      print(iNode);
    }
  }

  /// Converts a SemanticsNode tree into a non-minified INode map.
  /// [parentTransform] is the accumulated transform from root to this node's parent.
    Map<String, dynamic> _semanticsNodeToINode(
      SemanticsNode node, Matrix4 parentTransform) {
    final Matrix4 accumulatedTransform = node.transform != null
        ? parentTransform.multiplied(node.transform!)
        : parentTransform;

    final globalRect =
        MatrixUtils.transformRect(accumulatedTransform, node.rect);

    final Map<String, String> attributes = {};

    if (node.label.isNotEmpty) {
      attributes['label'] = node.label;
    }

    attributes['style'] =
        'position:absolute;'
        'left:${globalRect.left.toStringAsFixed(1)}px;'
        'top:${globalRect.top.toStringAsFixed(1)}px;'
        'width:${globalRect.width.toStringAsFixed(1)}px;'
        'height:${globalRect.height.toStringAsFixed(1)}px;';

    final List<Map<String, dynamic>> childNodes = [];
    node.visitChildren((child) {
      childNodes.add(_semanticsNodeToINode(child, accumulatedTransform));
      return true;
    });

    if (node.label.isNotEmpty && childNodes.isEmpty) {
      childNodes.add({
        'nn': '#text',
        't': '#text',
        'nt': 3,
        'u': 'sem_${node.id}_text',
        'a': {'textContent': node.label},
        'c': <Map<String, dynamic>>[],
        'r': <Map<String, dynamic>>[],
        's': false,
      });
    }

    return {
      'nn': node.hasChildren ? 'DIV' : 'SPAN',
      't': node.hasChildren ? 'DIV' : 'SPAN',
      'nt': 1,
      'u': 'sem_${node.id}',
      'a': attributes,
      'c': childNodes,
      'r': <Map<String, dynamic>>[],
      's': false,
    };
  }

}
