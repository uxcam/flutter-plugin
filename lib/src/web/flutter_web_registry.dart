import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_uxcam/src/web/js_bridge.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_registry.dart';

/// Periodically pushes occlusion rects to the UXCam Web SDK.
class FlutterWebRegistry {
  FlutterWebRegistry._();

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  Timer? _rescanTimer;
  bool _isListening = false;
  int _lastOcclusionHash = 0;

  void start() {
    if (_isListening) return;
    _isListening = true;

    _rescanTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pushOcclusionRects(),
    );
  }

  void _pushOcclusionRects() {
    try {
      if (uxc == null) return;

      final rects = OcclusionRegistry.instance.getOcclusionRects();
      final jsonStr = jsonEncode(rects);
      final hash = jsonStr.hashCode;
      if (hash == _lastOcclusionHash) return;
      _lastOcclusionHash = hash;

      final jsRects = jsonParse(jsonStr.toJS) as JSArray;
      uxcInjectOcclusionRects(jsRects);
    } catch (e, st) {
      consoleLog('[UXCam-Flutter] Occlusion ERROR: $e\n$st'.toJS);
    }
  }

  void dispose() {
    _rescanTimer?.cancel();
    _rescanTimer = null;
    _lastOcclusionHash = 0;
    _isListening = false;
  }
}
