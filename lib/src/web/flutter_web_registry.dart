import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/web/js_bridge.dart';
import 'package:flutter_uxcam/src/web/web_tree_walker.dart';

/// Periodically walks the Flutter render tree and pushes an INodeMin
/// snapshot to the UXCam Web SDK via window.uxc.injectSnapshot().
class FlutterWebRegistry {
  FlutterWebRegistry._();

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  Timer? _rescanTimer;
  bool _isListening = false;
  int _lastSnapshotHash = 0;

  void start() {
    if (_isListening) return;
    _isListening = true;

    _rescanTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _collectAndPush(),
    );
  }

  void _collectAndPush() {
    try {
      final rootElement = WidgetsBinding.instance.rootElement;
      if (rootElement == null) return;

      final nodes = WebTreeWalker.instance.buildSnapshot(rootElement);

      final jsonStr = jsonEncode(nodes);
      final hash = jsonStr.hashCode;
      if (hash == _lastSnapshotHash) return;
      _lastSnapshotHash = hash;

      if (uxc == null) return;
      final jsNodes = jsonParse(jsonStr.toJS) as JSArray;
      uxcInjectSnapshot(jsNodes);
    } catch (e, st) {
      consoleLog('[UXCam-Flutter] ERROR: $e\n$st'.toJS);
    }
  }

  void dispose() {
    _rescanTimer?.cancel();
    _rescanTimer = null;
    _lastSnapshotHash = 0;
    WebTreeWalker.instance.resetUuids();
    _isListening = false;
  }
}
