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
  
  final _boxesForPosition = <ScrollPosition, Set<OcclusionReportingRenderBox>>{};
  final _positionListeners = <ScrollPosition, VoidCallback>{};
  final _scrollingListeners = <ScrollPosition, VoidCallback>{};
  final _velocityTrackers = <ScrollPosition, _VelocityTracker>{};

  int _frameSequence = 0;
  bool _flushScheduled = false;
  bool _pendingResetAfterUpdate = false;

  int _lastResetTimestamp = 0;
  static const int _resetIntervalMicros = 100000; // 100ms

  final OcclusionPlatformChannel _channel = const OcclusionPlatformChannel();


  void subscribeToScroll(
    ScrollPosition position,
    OcclusionReportingRenderBox box,
  ) {
    if (!_boxesForPosition.containsKey(position)) {
      final positionListener = () => _onScrollPositionChanged(position);
      final scrollingListener = () => _onScrollingStateChanged(position);

      _positionListeners[position] = positionListener;
      _scrollingListeners[position] = scrollingListener;
      _velocityTrackers[position] = _VelocityTracker();

      position.addListener(positionListener);
      position.isScrollingNotifier.addListener(scrollingListener);

      _boxesForPosition[position] = {};
    }

    _boxesForPosition[position]!.add(box);
  }

  void unsubscribeFromScroll(
    ScrollPosition position,
    OcclusionReportingRenderBox box,
  ) {
    final boxes = _boxesForPosition[position];
    if (boxes == null) return;

    boxes.remove(box);

    if (boxes.isEmpty) {
      final positionListener = _positionListeners.remove(position);
      final scrollingListener = _scrollingListeners.remove(position);

      if (positionListener != null) {
        position.removeListener(positionListener);
      }
      if (scrollingListener != null) {
        position.isScrollingNotifier.removeListener(scrollingListener);
      }

      _boxesForPosition.remove(position);
      _velocityTrackers.remove(position);
    }
  }

  double getVelocity(ScrollPosition position) {
    return _velocityTrackers[position]?.velocity ?? 0.0;
  }

  void _onScrollPositionChanged(ScrollPosition position) {
    _velocityTrackers[position]?.update(position.pixels);

    final boxes = _boxesForPosition[position];
    if (boxes == null || boxes.isEmpty) return;

    for (final box in boxes) {
      box.recalculateBounds();
    }
  }

  void _onScrollingStateChanged(ScrollPosition position) {
    final isScrolling = position.isScrollingNotifier.value;

    if (isScrolling) {
      if (_lastResetTimestamp == 0) {
        _lastResetTimestamp = DateTime.now().microsecondsSinceEpoch;
      }
    } else {
      _velocityTrackers[position]?.reset();
      _lastResetTimestamp = 0;

      final boxes = _boxesForPosition[position];
      if (boxes != null) {
        for (final box in boxes) {
          box.recalculateBounds();
        }
      }

      _scheduleFlush(resetAfterUpdate: true);
    }
  }

  void register(OcclusionReportingRenderBox box) {
    _registered.add(box);
    _dirty.add(box);
    _scheduleFlush();
  }

  void unregister(OcclusionReportingRenderBox box) {
    _registered.remove(box);
    _dirty.remove(box);
    _channel.sendRemoval(box.stableId, box.viewId);
  }

  void markDirty(OcclusionReportingRenderBox box) {
    if (!_registered.contains(box)) return;
    _dirty.add(box);
    _scheduleFlush();
  }

  void _scheduleFlush({bool resetAfterUpdate = false}) {
    if (resetAfterUpdate) {
      _pendingResetAfterUpdate = true;
    }

    if (_flushScheduled) return;
    _flushScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;

      final shouldReset = _pendingResetAfterUpdate;
      _pendingResetAfterUpdate = false;

      _flushUpdates(resetAfterUpdate: shouldReset);
    });
  }

  void _flushUpdates({bool resetAfterUpdate = false}) {
    if (_dirty.isEmpty && !resetAfterUpdate) return;

    _frameSequence++;

    final currentTimestamp = DateTime.now().microsecondsSinceEpoch;

    // Periodic reset every 100ms during scrolling
    final shouldPeriodicReset = !resetAfterUpdate &&
        _lastResetTimestamp > 0 &&
        (currentTimestamp - _lastResetTimestamp) >= _resetIntervalMicros;

    if (resetAfterUpdate || shouldPeriodicReset) {
      _lastResetTimestamp =
          _lastResetTimestamp > 0 ? currentTimestamp : _lastResetTimestamp;
    }

    final updates = <OcclusionUpdate>[];
    for (final box in _dirty) {
      updates.add(OcclusionUpdate(
        id: box.stableId,
        bounds: box.currentBounds,
        type: box.currentType,
        devicePixelRatio: box.devicePixelRatio,
        viewId: box.viewId,
        frameSequence: _frameSequence,
      ));
    }
    _dirty.clear();

    _channel.sendBatchUpdate(
      updates,
      resetAfterUpdate: resetAfterUpdate || shouldPeriodicReset,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _channel.clearAll();
    } else if (state == AppLifecycleState.resumed) {
      _dirty.addAll(_registered);
      _scheduleFlush();
    }
  }

  static bool debugShowOcclusions = false;

  void debugPrintState() {
    debugPrint(
      'OcclusionRegistry: ${_registered.length} registered, ${_dirty.length} dirty',
    );
    for (final box in _registered) {
      debugPrint('  - ${box.stableId}: ${box.currentBounds}');
    }
  }
}

class _VelocityTracker {
  double _lastPixels = 0.0;
  int _lastTimestamp = 0;
  double _velocity = 0.0;

  double get velocity => _velocity;

  void update(double pixels) {
    final now = DateTime.now().microsecondsSinceEpoch;

    if (_lastTimestamp > 0) {
      final timeDelta = now - _lastTimestamp;
      if (timeDelta > 0) {
        final pixelsDelta = pixels - _lastPixels;
        _velocity = (pixelsDelta / timeDelta) * 1000000;
      }
    }

    _lastPixels = pixels;
    _lastTimestamp = now;
  }

  void reset() {
    _velocity = 0.0;
    _lastTimestamp = 0;
  }
}
