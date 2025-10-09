
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'occlusion_data.dart';
import 'visibility_tracer_info.dart';
import 'visibility_tracker.dart';

/// Manages all visibility tracking across the app
class VisibilityManager {
  static final VisibilityManager instance = VisibilityManager._internal();
  factory VisibilityManager() => instance;
  VisibilityManager._internal() {
    print('[VisibilityManager] Initialized');
  }

  final Map<String, VisibilityTrackerInfo> _trackedWidgets = {};
  final Map<String, WeakReference<VisibilityTrackerState>> _widgetRefs = {};
  Timer? _periodicTimer;
  int _activeWidgetCount = 0;
  // Notifies listeners whenever visibility info changes
  final ValueNotifier<int> updates = ValueNotifier<int>(0);

  void _notifyUpdate() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      updates.value++;
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        updates.value++;
      });
    }
  }

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    if (_activeWidgetCount > 0) {
      _periodicTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        _checkAllWidgets();
      });
    }
  }

  void _stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _checkAllWidgets() {
    final List<String> toRemove = [];
    
    _widgetRefs.forEach((id, ref) {
      final state = ref.target;
      if (state != null && state.mounted) {
        state.checkVisibility();
      } else {
        toRemove.add(id);
      }
    });

    for (final id in toRemove) {
      removeWidget(id);
    }
  }

  void registerWidget(String id, VisibilityTrackerState state) {
    _widgetRefs[id] = WeakReference(state);
    _activeWidgetCount++;
    if (_activeWidgetCount == 1) {
      _startPeriodicCheck();
    }
    print('[VisibilityManager] Widget registered: $id (total: $_activeWidgetCount)');
  }

  void updateVisibility(String id, VisibilityTrackerInfo info) {
    final oldInfo = _trackedWidgets[id];
    // Always keep the latest info so downstream fetches aren't stale
    _trackedWidgets[id] = info;

    print('[VisibilityManager] updateVisibility: $_trackedWidgets.length');
    if (oldInfo == null || _hasChanged(oldInfo, info)) {
      if (info.isVisible) {
        // print('[VisibilityManager] $id is VISIBLE (${(info.visibilityFraction * 100).toStringAsFixed(0)}%)');
      } else if (oldInfo?.isVisible == true) {
        // print('[VisibilityManager] $id is HIDDEN');
      }
    }
    // Notify listeners of any update (defer if tree is locked)
    _notifyUpdate();
  }

  bool _hasChanged(VisibilityTrackerInfo old, VisibilityTrackerInfo new_) {
    return old.isVisible != new_.isVisible ||
           (old.visibilityFraction - new_.visibilityFraction).abs() > 0.05 ||
           old.bounds != new_.bounds;
  }

  void removeWidget(String id) {
    _trackedWidgets.remove(id);
    _widgetRefs.remove(id);
    _activeWidgetCount--;
    
    if (_activeWidgetCount == 0) {
      _stopPeriodicCheck();
    }
    
    // print('[VisibilityManager] Widget removed: $id (remaining: $_activeWidgetCount)');
    _notifyUpdate();
  }

  VisibilityTrackerInfo? getVisibilityInfo(String id) => _trackedWidgets[id];

  List<Map<String, dynamic>> rectList = [];

  void addRect(Map<String, dynamic> rect) {
    rectList.add(rect);
  }

  /// Fetch occlusion rects in the same format as OcclusionWrapperManager.fetchOcclusionRects()
  List<Map<String, dynamic>> fetchOcclusionRects() {
    List<Map<String, dynamic>> occlusionRects = [];
    
    print('[VisibilityManager] fetchOcclusionRects: ${_trackedWidgets.values.length}');
    for (final info in _trackedWidgets.values) {
      if (info.isVisible && info.bounds != null) {
        final occludePoint = info.toOccludePoint();
        occlusionRects.add(occludePoint.toJson());
      }
    }
    print('[VisibilityManager] fetchOcclusionRects: $occlusionRects');
    return occlusionRects;
  }

  /// Get all occlude points similar to OcclusionWrapperManager.getOccludePoints()
  List<OccludePoint> getOccludePoints() {
    List<OccludePoint> occludePoints = [];
    
    for (final info in _trackedWidgets.values) {
      if (info.isVisible && info.bounds != null) {
        occludePoints.add(info.toOccludePoint());
      }
    }
    
    return occludePoints;
  }

  /// Get occlude point for specific widget ID
  OccludePoint? getOccludePoint(String id) {
    final info = _trackedWidgets[id];
    if (info != null && info.isVisible && info.bounds != null) {
      return info.toOccludePoint();
    }
    return null;
  }

  Map<String, VisibilityTrackerInfo> getAllVisibleWidgets() {
    return Map.from(_trackedWidgets)
      ..removeWhere((key, value) => !value.isVisible);
  }

  void dispose() {
    _periodicTimer?.cancel();
    _trackedWidgets.clear();
    _widgetRefs.clear();
    _activeWidgetCount = 0;
  }
}