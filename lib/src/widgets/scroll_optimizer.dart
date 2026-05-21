import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Velocity + stability scroll skip detector for the synchronized capture
/// tick. Pointer state is process-global; install() is idempotent.
class ScrollOptimizer {
  ScrollOptimizer._();

  static const int _scrollIdleGraceMs = 150;
  static const double _scrollMoveThresholdSquared = 4.0; // ~2 logical px
  static const double _fastScrollPxPerSec = 800.0;
  static const int _stableIdleMs = 32; // 2 vsync frames at 60 Hz
  static const int _maxConsecutiveScrollSkips = 5;
  static const int _maxVelocitySamples = 6;

  static bool _installed = false;
  static int _activePointerCount = 0;
  static int _lastMoveAtMs = 0;
  static int? _trackedPointer;
  static final List<_VelocitySample> _samples = <_VelocitySample>[];
  static int _consecutiveScrollSkips = 0;

  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }

  /// Returns 'scroll_fast' / 'scroll_unstable' to skip this tick, or null
  /// to proceed. Advances the consecutive-skip counter — call once per tick.
  static String? evaluateSkipReason() {
    if (!_isLikelyScrolling()) {
      _consecutiveScrollSkips = 0;
      return null;
    }
    // Starvation cap applies regardless of skip reason: after this many
    // consecutive scroll-induced skips, force one frame through.
    if (_consecutiveScrollSkips >= _maxConsecutiveScrollSkips) {
      _consecutiveScrollSkips = 0;
      return null;
    }
    if (_currentVelocityPxPerSec() > _fastScrollPxPerSec) {
      _consecutiveScrollSkips++;
      return 'scroll_fast';
    }
    if (!_isStableMoment()) {
      _consecutiveScrollSkips++;
      return 'scroll_unstable';
    }
    _consecutiveScrollSkips = 0;
    return null;
  }

  static void _onPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _activePointerCount++;
      // First pointer drives the velocity track; multi-touch ignored.
      if (_trackedPointer == null) {
        _trackedPointer = event.pointer;
        _samples
          ..clear()
          ..add(_VelocitySample(event.timeStamp, event.position));
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_activePointerCount > 0) _activePointerCount--;
      if (event.pointer == _trackedPointer) {
        _trackedPointer = null;
        _samples.clear();
      }
    } else if (event is PointerMoveEvent) {
      if (event.delta.distanceSquared > _scrollMoveThresholdSquared) {
        _lastMoveAtMs = _nowMs();
      }
      if (event.pointer == _trackedPointer) {
        _samples.add(_VelocitySample(event.timeStamp, event.position));
        if (_samples.length > _maxVelocitySamples) {
          _samples.removeAt(0);
        }
      }
    }
  }

  static bool _isLikelyScrolling() {
    if (_activePointerCount == 0) return false;
    final int ageMs = _nowMs() - _lastMoveAtMs;
    return ageMs >= 0 && ageMs <= _scrollIdleGraceMs;
  }

  /// Magnitude of current scroll velocity (logical px / s) over the trailing
  /// sample window. Returns 0 with fewer than 2 samples or zero elapsed time.
  static double _currentVelocityPxPerSec() {
    if (_samples.length < 2) return 0.0;
    final _VelocitySample first = _samples.first;
    final _VelocitySample last = _samples.last;
    final double dtSec =
        (last.timeStamp - first.timeStamp).inMicroseconds / 1e6;
    if (dtSec <= 0) return 0.0;
    return (last.position - first.position).distance / dtSec;
  }

  static bool _isStableMoment() {
    final int ageMs = _nowMs() - _lastMoveAtMs;
    return ageMs >= _stableIdleMs;
  }

  // --- Test seam ---

  /// Test-injectable clock. Production reads system time; tests override to
  /// advance time deterministically.
  @visibleForTesting
  static int Function() debugNowMs =
      () => DateTime.now().millisecondsSinceEpoch;

  /// Resets all mutable state. Tests call this in setUp to isolate each case.
  @visibleForTesting
  static void debugReset() {
    _activePointerCount = 0;
    _lastMoveAtMs = 0;
    _trackedPointer = null;
    _samples.clear();
    _consecutiveScrollSkips = 0;
  }

  /// Direct pointer-event entry point for tests, bypassing the
  /// GestureBinding global router (not reliably available in unit tests).
  @visibleForTesting
  static void debugFeedPointerEvent(PointerEvent event) =>
      _onPointerEvent(event);

  static int _nowMs() => debugNowMs();
}

class _VelocitySample {
  const _VelocitySample(this.timeStamp, this.position);
  final Duration timeStamp;
  final Offset position;
}
