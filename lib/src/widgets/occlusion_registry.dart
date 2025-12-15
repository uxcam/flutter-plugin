import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_models.dart';

class OcclusionRegistry with WidgetsBindingObserver {
  OcclusionRegistry._() {
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannelHandler();
    _setupPersistentFrameCallback();
  }

  static final OcclusionRegistry instance = OcclusionRegistry._();

  final _registered = <OcclusionReportingRenderBox>{};

  static const MethodChannel _requestChannel =
      MethodChannel('uxcam_occlusion_request');

  void _setupMethodChannelHandler() {
    _requestChannel.setMethodCallHandler(_handleMethodCall);
  }

  void _setupPersistentFrameCallback() {
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (_registered.isEmpty) return;

    final snapshot = _registered.toList();

    for (final box in snapshot) {
      if (box.attached && box.hasSize) {
        box.updateBoundsFromTransform();
      }
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestOcclusionRects':
        return _handleCachedRectsRequest();
      default:
        throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'Method ${call.method} not supported',
        );
    }
  }

  List<Map<String, dynamic>> _handleCachedRectsRequest() {

    final registeredSnapshot = _registered.toList();
    final rects = <Map<String, dynamic>>[];

    for (final box in registeredSnapshot) {
      if (!box.attached) continue;

      final bounds = box.getUnionOfHistoricalBounds();
      if (bounds == null || bounds.width <= 0 || bounds.height <= 0) continue;

      final dpr = box.devicePixelRatio;
      rects.add({
        'id': box.stableId,
        'left': (bounds.left * dpr).roundToDouble(),
        'top': (bounds.top * dpr).roundToDouble(),
        'right': (bounds.right * dpr).roundToDouble(),
        'bottom': (bounds.bottom * dpr).roundToDouble(),
        'type': box.currentType.index,
      });
    }

    return rects;
  }

  void register(OcclusionReportingRenderBox box) {
    _registered.add(box);
  }

  void unregister(OcclusionReportingRenderBox box) {
    _registered.remove(box);
  }

}
