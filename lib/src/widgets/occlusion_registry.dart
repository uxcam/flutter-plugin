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

  static const _detachedTtlMs = 1500;

  final Map<int, _OcclusionEntry> _entries = {};

  static const MethodChannel _requestChannel =
      MethodChannel('uxcam_occlusion_request');

  void _setupMethodChannelHandler() {
    _requestChannel.setMethodCallHandler(_handleMethodCall);
  }

  void _setupPersistentFrameCallback() {
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (_entries.isEmpty) return;

    final snapshot = _entries.values.toList();

    for (final entry in snapshot) {
      final box = entry.box;
      if (entry.attached && box != null && box.attached && box.hasSize) {
        box.updateBoundsFromTransform();
        _refreshEntryFromBox(entry, box);
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

  /// Public method for synchronized capture handler to get cached rects.
  /// Returns the current occlusion rects using historical bounds union.
  List<Map<String, dynamic>> getCachedRects() {
    return _handleCachedRectsRequest();
  }

  List<Map<String, dynamic>> _handleCachedRectsRequest() {
    final requestTimestamp = DateTime.now().millisecondsSinceEpoch;

    _expireStaleEntries(requestTimestamp);

    final rects = <Map<String, dynamic>>[];
    final snapshot = _entries.values.toList();

    for (final entry in snapshot) {
      if (entry.attached) {
        final box = entry.box;
        if (box == null || !box.attached || !box.hasSize) {
          final canUseCache =
              entry.lastBounds != null &&
              (requestTimestamp - entry.lastUpdatedMs) <= _detachedTtlMs;
          if (canUseCache) {
            final rectData = _rectDataFromEntry(entry, entry.lastBounds!);
            rects.add(rectData);
          }
          continue;
        }

        box.updateBoundsFromTransform();

        final bounds = box.getUnionOfHistoricalBounds();
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }

        _refreshEntryFromBox(entry, box, overrideBounds: bounds);
        final rectData = _rectDataFromEntry(entry, bounds);
        rects.add(rectData);
      } else {
        final bounds = entry.lastBounds;
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }
        final rectData = _rectDataFromEntry(entry, bounds);
        rects.add(rectData);
      }
    }

    return rects;
  }

  void register(OcclusionReportingRenderBox box) {
    final entry = _entries[box.stableId] ?? _OcclusionEntry(id: box.stableId);
    entry
      ..box = box
      ..attached = true;
    _refreshEntryFromBox(entry, box);
    _entries[box.stableId] = entry;
  }

  void markDetached(OcclusionReportingRenderBox box) {
    final entry = _entries[box.stableId];
    if (entry == null) {
      return;
    }

    entry
      ..attached = false
      ..box = null
      ..lastBounds = box.getUnionOfHistoricalBounds()
      ..lastUpdatedMs = DateTime.now().millisecondsSinceEpoch
      ..devicePixelRatio = box.devicePixelRatio
      ..viewId = box.viewId
      ..type = box.currentType;
  }

  void remove(OcclusionReportingRenderBox box) {
    _entries.remove(box.stableId);
  }

  void _refreshEntryFromBox(
    _OcclusionEntry entry,
    OcclusionReportingRenderBox box, {
    Rect? overrideBounds,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    entry
      ..lastBounds = overrideBounds ?? box.currentBounds
      ..lastUpdatedMs = now
      ..devicePixelRatio = box.devicePixelRatio
      ..viewId = box.viewId
      ..type = box.currentType;
  }

  Map<String, dynamic> _rectDataFromEntry(_OcclusionEntry entry, Rect bounds) {
    final dpr = entry.devicePixelRatio ?? 1.0;
    return {
      'id': entry.id,
      'left': (bounds.left * dpr).roundToDouble(),
      'top': (bounds.top * dpr).roundToDouble(),
      'right': (bounds.right * dpr).roundToDouble(),
      'bottom': (bounds.bottom * dpr).roundToDouble(),
      'type': (entry.type ?? OcclusionType.overlay).index,
    };
  }

  void _expireStaleEntries(int nowMs) {
    _entries.removeWhere(
      (_, entry) =>
          !entry.attached && (nowMs - entry.lastUpdatedMs) > _detachedTtlMs,
    );
  }
}

class _OcclusionEntry {
  _OcclusionEntry({required this.id});

  final int id;
  OcclusionReportingRenderBox? box;
  Rect? lastBounds;
  double? devicePixelRatio;
  int? viewId;
  OcclusionType? type;
  int lastUpdatedMs = 0;
  bool attached = false;
}
