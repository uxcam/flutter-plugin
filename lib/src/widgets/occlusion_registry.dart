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

  int _frameSequence = 0;

  bool _flushScheduled = false;
  bool _pendingResetAfterUpdate = false;

  int _lastResetTimestamp = 0;
  static const int _resetIntervalMicros = 100000; // 100ms in microseconds

  final OcclusionPlatformChannel _channel = const OcclusionPlatformChannel();

  final Map<ScrollPosition, _ScrollSubscription> _scrollSubscriptions = {};

  void subscribeToScroll(ScrollPosition position, ScrollSubscriber subscriber) {
    if (!_scrollSubscriptions.containsKey(position)) {
      final subscription = _ScrollSubscription(position, this);
      _scrollSubscriptions[position] = subscription;
      subscription.attach();
    }
    _scrollSubscriptions[position]!.subscribers.add(subscriber);
  }

  void unsubscribeFromScroll(
    ScrollPosition position,
    ScrollSubscriber subscriber,
  ) {
    final subscription = _scrollSubscriptions[position];
    if (subscription == null) return;

    subscription.subscribers.remove(subscriber);

    if (subscription.subscribers.isEmpty) {
      subscription.detach();
      _scrollSubscriptions.remove(position);
    }
  }

  void _notifyScrollPositionChanged(ScrollPosition position) {
    final subscription = _scrollSubscriptions[position];
    if (subscription == null || subscription.subscribers.isEmpty) return;

    for (final subscriber in subscription.subscribers) {
      subscriber.onScrollPositionChanged();
    }
  }

  void _notifyScrollStateChanged(ScrollPosition position) {
    final subscription = _scrollSubscriptions[position];
    if (subscription == null || subscription.subscribers.isEmpty) return;

    final isScrolling = position.isScrollingNotifier.value;

    for (final subscriber in subscription.subscribers) {
      subscriber.onScrollStateChanged(isScrolling);
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
    final shouldPeriodicReset = !resetAfterUpdate &&
        _lastResetTimestamp > 0 &&
        (currentTimestamp - _lastResetTimestamp) >= _resetIntervalMicros;

    if (resetAfterUpdate || shouldPeriodicReset) {
      _lastResetTimestamp = currentTimestamp;
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

  void signalMotionStarted() {
    _lastResetTimestamp = DateTime.now().microsecondsSinceEpoch;
  }

  void signalMotionEnded() {
    _lastResetTimestamp = 0;

    for (final box in _registered) {
      box.recalculateBounds();
    }

    _dirty.addAll(_registered);

    _flushUpdates(resetAfterUpdate: true);
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

class _ScrollSubscription {
  _ScrollSubscription(this.position, this.registry);

  final ScrollPosition position;
  final OcclusionRegistry registry;
  final Set<ScrollSubscriber> subscribers = {};

  void attach() {
    position.addListener(_onPositionChanged);
    position.isScrollingNotifier.addListener(_onScrollStateChanged);
  }

  void detach() {
    position.removeListener(_onPositionChanged);
    position.isScrollingNotifier.removeListener(_onScrollStateChanged);
  }

  void _onPositionChanged() {
    registry._notifyScrollPositionChanged(position);
  }

  void _onScrollStateChanged() {
    registry._notifyScrollStateChanged(position);
  }
}
