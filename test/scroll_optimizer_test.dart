import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/scroll_optimizer.dart';

/// Behavioral tests for ScrollOptimizer's velocity + stability skip policy.
///
/// The optimizer's contract:
///   • Not scrolling          → null         (capture)
///   • Cap reached (≥5 skips) → null         (force one through)
///   • Fast velocity          → 'scroll_fast'
///   • Slow + unstable        → 'scroll_unstable'
///   • Slow + stable          → null         (capture)
///
/// All time-dependent state is driven through the injected debug clock so
/// tests are deterministic.
void main() {
  // VelocityTracker reaches into GestureBinding.instance for its sampling
  // clock, so the test binding must exist before the first event is fed.
  TestWidgetsFlutterBinding.ensureInitialized();

  late int now;

  setUp(() {
    now = 1000000;
    ScrollOptimizer.debugNowMs = () => now;
    ScrollOptimizer.debugReset();
  });

  tearDown(() {
    ScrollOptimizer.debugNowMs = () => DateTime.now().millisecondsSinceEpoch;
    ScrollOptimizer.debugReset();
  });

  void advance(int ms) {
    now += ms;
  }

  void feedDown({int pointer = 1, Offset position = const Offset(100, 100)}) {
    ScrollOptimizer.debugFeedPointerEvent(PointerDownEvent(
      pointer: pointer,
      position: position,
      timeStamp: Duration(milliseconds: now),
    ));
  }

  void feedMove({
    int pointer = 1,
    required Offset position,
    required Offset delta,
  }) {
    ScrollOptimizer.debugFeedPointerEvent(PointerMoveEvent(
      pointer: pointer,
      position: position,
      delta: delta,
      timeStamp: Duration(milliseconds: now),
    ));
  }

  void feedUp({int pointer = 1, Offset position = const Offset(100, 100)}) {
    ScrollOptimizer.debugFeedPointerEvent(PointerUpEvent(
      pointer: pointer,
      position: position,
      timeStamp: Duration(milliseconds: now),
    ));
  }

  void feedCancel({int pointer = 1}) {
    ScrollOptimizer.debugFeedPointerEvent(PointerCancelEvent(
      pointer: pointer,
      timeStamp: Duration(milliseconds: now),
    ));
  }

  /// Simulates a continuous finger drag: feeds `samples` move events spaced
  /// `stepMs` apart with `stepDelta` displacement per step. VelocityTracker
  /// needs ≥3 samples within 100 ms to produce a confident estimate.
  void simulateDrag({
    required int samples,
    required int stepMs,
    required Offset stepDelta,
    Offset start = const Offset(100, 100),
  }) {
    Offset pos = start;
    for (int i = 0; i < samples; i++) {
      advance(stepMs);
      pos += stepDelta;
      feedMove(position: pos, delta: stepDelta);
    }
  }

  group('not scrolling', () {
    test('idle screen → capture', () {
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });

    test('pointer down with no movement → capture', () {
      feedDown();
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });

    test('tap (sub-threshold jitter) → capture', () {
      feedDown(position: const Offset(100, 100));
      // 1 px move is below sqrt(4.0) ≈ 2 px threshold.
      advance(5);
      feedMove(
        position: const Offset(101, 100),
        delta: const Offset(1, 0),
      );
      feedUp(position: const Offset(101, 100));
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });

    test('long-press (pointer down, no motion) → capture', () {
      feedDown();
      advance(2000);
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });
  });

  group('idle grace', () {
    test('motion >150 ms ago → no longer scrolling → capture', () {
      feedDown();
      simulateDrag(samples: 5, stepMs: 10, stepDelta: const Offset(50, 0));
      // Verify the drag did classify as scrolling first.
      expect(ScrollOptimizer.evaluateSkipReason(), isNotNull);
      ScrollOptimizer.debugReset();

      feedDown();
      simulateDrag(samples: 5, stepMs: 10, stepDelta: const Offset(50, 0));
      advance(151);
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });
  });

  group('fast scroll', () {
    void primeFastVelocity() {
      // 50 px every 10 ms ≈ 5000 px/s, well above the 800 px/s threshold.
      feedDown();
      simulateDrag(samples: 6, stepMs: 10, stepDelta: const Offset(50, 0));
    }

    test('fast velocity → scroll_fast skip', () {
      primeFastVelocity();
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');
    });

    test('5 consecutive fast skips then cap forces one through', () {
      primeFastVelocity();
      for (int i = 0; i < 5; i++) {
        if (i > 0) {
          // Refresh motion before each tick — keeps us inside the
          // _scrollIdleGraceMs window so still classified as scrolling.
          simulateDrag(
            samples: 3,
            stepMs: 10,
            stepDelta: const Offset(50, 0),
          );
        }
        expect(
          ScrollOptimizer.evaluateSkipReason(),
          'scroll_fast',
          reason: 'tick ${i + 1} of 5 should skip',
        );
      }
      // Counter is now at 5 → 6th call fires the cap.
      simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(
        ScrollOptimizer.evaluateSkipReason(),
        isNull,
        reason: 'cap should force the 6th tick through',
      );
    });

    test('cap reset starts a fresh skip burst', () {
      primeFastVelocity();
      // Burn 5 skips.
      for (int i = 0; i < 5; i++) {
        if (i > 0) {
          simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
        }
        ScrollOptimizer.evaluateSkipReason();
      }
      simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), isNull); // cap fires
      // Continue fast scrolling: next tick should skip again from 0.
      simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');
    });
  });

  group('slow scroll', () {
    void primeSlowVelocity() {
      // 5 px every 50 ms = 100 px/s, well below 800 px/s threshold.
      feedDown();
      simulateDrag(samples: 4, stepMs: 50, stepDelta: const Offset(5, 0));
    }

    test('slow velocity + recent motion → scroll_unstable skip', () {
      primeSlowVelocity();
      // Immediately query while still within stable-idle window.
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_unstable');
    });

    test('slow velocity + stable pause (≥32 ms) → capture', () {
      primeSlowVelocity();
      // Pause long enough for the stable-moment threshold but stay within
      // the scroll-idle grace window so still classified as scrolling.
      advance(40);
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });

    test('continuous slow drag (no pauses) also caps after 5 skips', () {
      // Regression: the cap originally lived only in the fast lane, which
      // meant a long continuous slow drag could starve the recording.
      primeSlowVelocity();
      for (int i = 0; i < 5; i++) {
        expect(
          ScrollOptimizer.evaluateSkipReason(),
          'scroll_unstable',
          reason: 'tick ${i + 1} of 5 should skip',
        );
        // Sustain the drag — fresh motion within the idle-grace window
        // keeps both "is scrolling" true and "is stable" false.
        simulateDrag(samples: 2, stepMs: 10, stepDelta: const Offset(5, 0));
      }
      expect(
        ScrollOptimizer.evaluateSkipReason(),
        isNull,
        reason: 'cap should fire on the 6th unstable tick too',
      );
    });
  });

  group('counter resets', () {
    test('non-scroll tick after skip burst resets counter', () {
      // Burn a few skips during fast scroll.
      feedDown();
      simulateDrag(samples: 6, stepMs: 10, stepDelta: const Offset(50, 0));
      ScrollOptimizer.evaluateSkipReason();
      ScrollOptimizer.evaluateSkipReason();
      // Lift finger → no longer scrolling.
      feedUp();
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);

      // New fast scroll should start a fresh skip burst from zero.
      feedDown(position: const Offset(100, 100));
      simulateDrag(samples: 6, stepMs: 10, stepDelta: const Offset(50, 0));
      for (int i = 0; i < 5; i++) {
        expect(
          ScrollOptimizer.evaluateSkipReason(),
          'scroll_fast',
          reason: 'new burst tick ${i + 1} of 5',
        );
        simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      }
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });

    test('stable-moment capture resets counter mid-scroll', () {
      // Slow drag, accumulate 2 unstable skips.
      feedDown();
      simulateDrag(samples: 4, stepMs: 50, stepDelta: const Offset(5, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_unstable');
      simulateDrag(samples: 2, stepMs: 10, stepDelta: const Offset(5, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_unstable');

      // Pause → captures. Counter resets.
      advance(40);
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);

      // Resume unstable drag. Counter starts from 0 again, not from 2.
      for (int i = 0; i < 5; i++) {
        simulateDrag(samples: 2, stepMs: 10, stepDelta: const Offset(5, 0));
        expect(
          ScrollOptimizer.evaluateSkipReason(),
          'scroll_unstable',
          reason: 'resumed burst tick ${i + 1}',
        );
      }
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });
  });

  group('mixed reasons', () {
    test('cap budget shared between fast and unstable lanes', () {
      feedDown();
      // Prime with mixed velocity moves.
      simulateDrag(samples: 6, stepMs: 10, stepDelta: const Offset(50, 0));
      // 3 fast skips.
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');
      simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');
      simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');

      // Now keep finger still long enough for velocity to decay, then do
      // tiny moves so it's slow + unstable.
      advance(120);
      simulateDrag(samples: 4, stepMs: 50, stepDelta: const Offset(5, 0));
      // Counter is now at 3 from the fast skips. 2 more unstable skips →
      // 5 total → 6th call fires the cap.
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_unstable');
      simulateDrag(samples: 2, stepMs: 10, stepDelta: const Offset(5, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_unstable');
      simulateDrag(samples: 2, stepMs: 10, stepDelta: const Offset(5, 0));
      expect(
        ScrollOptimizer.evaluateSkipReason(),
        isNull,
        reason: 'cap fires after 5 mixed skips',
      );
    });
  });

  group('pointer lifecycle', () {
    test('pointer cancel ends velocity tracking', () {
      feedDown();
      simulateDrag(samples: 6, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');
      feedCancel();
      // After cancel + idle, no longer scrolling.
      advance(160);
      expect(ScrollOptimizer.evaluateSkipReason(), isNull);
    });

    test('multi-touch: second pointer down does not disturb velocity track',
        () {
      // First pointer establishes fast-scroll velocity.
      feedDown(pointer: 1);
      simulateDrag(samples: 6, stepMs: 10, stepDelta: const Offset(50, 0));

      // Second finger lands — first pointer's velocity must keep counting.
      feedDown(pointer: 2, position: const Offset(200, 200));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');

      // Second finger lifts; velocity tracker is bound to pointer 1, so
      // this should not stop tracking.
      feedUp(pointer: 2, position: const Offset(200, 200));
      simulateDrag(samples: 3, stepMs: 10, stepDelta: const Offset(50, 0));
      expect(ScrollOptimizer.evaluateSkipReason(), 'scroll_fast');
    });
  });
}
