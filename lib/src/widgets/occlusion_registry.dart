import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_models.dart';
import 'occlusion_platform_channel.dart';

class OcclusionRegistry with WidgetsBindingObserver {
  OcclusionRegistry._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final OcclusionRegistry instance = OcclusionRegistry._();

  final _registered = <OcclusionReportingRenderBox>{};
  final _dirty = <OcclusionReportingRenderBox>{};
  bool _frameCallbackScheduled = false;

  final OcclusionPlatformChannel _channel = const OcclusionPlatformChannel();

  void register(OcclusionReportingRenderBox box) {
    _registered.add(box);
    _dirty.add(box);
    _scheduleUpdate();
  }

  void unregister(OcclusionReportingRenderBox box) {
    _registered.remove(box);
    _dirty.remove(box);
    _channel.sendRemoval(box.stableId, box.viewId);
  }

  void markDirty(OcclusionReportingRenderBox box) {
    if (!_registered.contains(box)) return;
    _dirty.add(box);
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    if (_frameCallbackScheduled) return;
    _frameCallbackScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameCallbackScheduled = false;
      _flushUpdates();
    });
  }

  void _flushUpdates() {
    if (_dirty.isEmpty) return;

    final updates = <OcclusionUpdate>[];
    for (final box in _dirty) {
      updates.add(OcclusionUpdate(
        id: box.stableId,
        bounds: box.currentBounds,
        type: box.currentType,
        devicePixelRatio: box.devicePixelRatio,
        viewId: box.viewId,
      ));
    }
    _dirty.clear();

    _channel.sendBatchUpdate(updates);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _channel.clearAll();
    } else if (state == AppLifecycleState.resumed) {
      _dirty.addAll(_registered);
      _scheduleUpdate();
    }
  }

  static bool debugShowOcclusions = false;

  void debugPrintState() {
    debugPrint(
        'OcclusionRegistry: ${_registered.length} registered, ${_dirty.length} dirty');
    for (final box in _registered) {
      debugPrint('  - ${box.stableId}: ${box.currentBounds}');
    }
  }
}
