import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/stretch_map.dart';

// Goldens shared with the Android SDK's StretchMapTest.kt.
void main() {
  const s = 0.032;

  test('top-anchored map matches the hand-computed goldens', () {
    expect(StretchMap.computeReverseOverscroll(s, 0), closeTo(0, 1e-9));
    expect(
        StretchMap.computeReverseOverscroll(s, 0.25), closeTo(0.2622232, 1e-6));
    expect(
        StretchMap.computeReverseOverscroll(s, 0.5), closeTo(0.5214790, 1e-6));
    expect(
        StretchMap.computeReverseOverscroll(s, 1 / (1 + s)), closeTo(1, 1e-9));
  });

  test('the anchored edge does not move, either way round', () {
    expect(StretchMap.computeReverseOverscroll(s, 0), closeTo(0, 1e-9));
    expect(StretchMap.computeReverseOverscroll(-s, 1), closeTo(1, 1e-9));
  });

  test('the two helpers mirror each other', () {
    for (var i = 0; i <= 20; i++) {
      final u = i / 20;
      expect(StretchMap.reverseMapEnd(-s, u),
          closeTo(1 - StretchMap.reverseMapStart(s, 1 - u), 1e-9));
    }
  });

  test('zero overscroll is the identity', () {
    for (final u in [0.0, 0.2, 0.5, 0.8, 1.0]) {
      expect(StretchMap.computeReverseOverscroll(0, u), u);
    }
  });

  test('displacement grows with s, past the Android cap too', () {
    var last = 0.0;
    for (final strength in [0.01, 0.032, 0.1, 0.3, 1.0]) {
      final moved = StretchMap.computeReverseOverscroll(strength, 0.5) - 0.5;
      expect(moved, greaterThan(last));
      last = moved;
    }
  });

  test('remapRect moves only its own axis', () {
    const container = Rect.fromLTWH(0, 0, 1080, 2300);
    const box = Rect.fromLTWH(100, 1000, 300, 150);
    final down = StretchMap.remapRect(box, container, Axis.vertical, s);
    expect(down.left, box.left);
    expect(down.right, box.right);
    expect(down.top, greaterThan(box.top));
    expect(down.bottom, greaterThan(box.bottom));
    final up = StretchMap.remapRect(box, container, Axis.vertical, -s);
    expect(up.top, lessThan(box.top));
    final side = StretchMap.remapRect(box, container, Axis.horizontal, s);
    expect(side.top, box.top);
    expect(side.bottom, box.bottom);
    expect(side.left, greaterThan(box.left));
  });

  test('a degenerate container leaves the rect alone', () {
    const box = Rect.fromLTWH(10, 10, 20, 20);
    expect(StretchMap.remapRect(box, Rect.zero, Axis.vertical, s), box);
  });
}
