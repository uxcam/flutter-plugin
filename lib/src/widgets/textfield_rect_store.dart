import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'occlusion_models.dart';
import 'occlusion_rect_codec.dart';
import 'textfield_detector.dart';
import 'textfield_occlude_render_box.dart';

/// Holds the auto text-field occlusion state, **separately** from the
/// wrapper/config occlusion entries, bucketed by the screen a field was first
/// discovered on.
///
/// Design rules (each closes a concrete defect):
///  * **First-discovery attribution.** An adapter stays in the bucket where it
///    was first discovered and is never re-bucketed. During a route transition
///    both screens are mounted, so a scan runs while the *outgoing* screen's
///    fields are still in the tree — re-bucketing them under the incoming
///    screen used to leave the old bucket serving stale positions.
///  * **Live serialization.** Rects are serialized from the adapters' current
///    state at request time (O(#fields), no tree walk), so a served rect is
///    either live or an explicit short-grace ghost — never a stale cache.
///  * **Detach grace.** When a field leaves the tree (rebuild, route pop), its
///    last bounds are served for [graceTtlMs] so a capture that races the
///    detach never shows the field unmasked mid-frame.
class TextFieldRectStore {
  TextFieldRectStore({int Function()? clock}) : _clock = clock ?? _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  /// How long a detached field's last bounds keep being served.
  static const int graceTtlMs = 500;

  final int Function() _clock;

  final Map<String, _ScreenBucket> _buckets = {};

  /// Attribution index: adapter stableId → the bucket it was first discovered
  /// in. Prevents re-bucketing during transitions.
  final Map<int, String> _adapterScreen = {};

  bool get isEmpty => _buckets.isEmpty;

  @visibleForTesting
  int get adapterCount =>
      _buckets.values.fold(0, (sum, b) => sum + b.adapters.length);

  /// Tier-2 (discovery): reconciles the scan result into the store. New fields
  /// are attributed to [activeScreenKey]; already-known fields keep their
  /// original bucket. Removal is NOT done here — tier-1 prunes by detachment,
  /// which is authoritative and runs every frame.
  void reconcile(String activeScreenKey, Map<int, DiscoveredField> discovered) {
    for (final field in discovered.values) {
      final id = TextFieldOccludeRenderBox.stableIdFor(field.box);
      final existingKey = _adapterScreen[id];
      if (existingKey != null &&
          (_buckets[existingKey]?.adapters.containsKey(id) ?? false)) {
        continue; // known field — keep original attribution
      }
      final bucket =
          _buckets.putIfAbsent(activeScreenKey, () => _ScreenBucket());
      bucket.adapters[id] = TextFieldOccludeRenderBox(
        field.box,
        addPadding: field.isBareEditable,
        clock: _clock,
      );
      _adapterScreen[id] = activeScreenKey;
    }
  }

  /// Moves detached adapters to grace, expires grace, drops empty buckets, and —
  /// when [refreshBounds] is set — re-resolves each live adapter's bounds.
  ///
  /// Detach bookkeeping must never lag the frame a field leaves the tree, since its
  /// grace rect covers a capture taken just before the detach. Bounds refresh is the
  /// expensive half and can be throttled.
  void updateBounds({bool refreshBounds = true}) {
    final nowMs = _clock();
    final emptyKeys = <String>[];
    _buckets.forEach((key, bucket) {
      bucket.adapters.removeWhere((id, adapter) {
        if (!adapter.attached || !adapter.hasSize) {
          final last = adapter.getUnionOfHistoricalBounds();
          if (last != null && last.width > 0 && last.height > 0) {
            bucket.graceRects.add(_GraceRect(
              id: id,
              bounds: last,
              devicePixelRatio: adapter.devicePixelRatio,
              expiresAtMs: nowMs + graceTtlMs,
            ));
          }
          _adapterScreen.remove(id);
          return true;
        }
        if (refreshBounds) {
          adapter.updateBoundsFromTransform();
        }
        return false;
      });
      bucket.graceRects.removeWhere((g) => g.expiresAtMs <= nowMs);
      if (bucket.adapters.isEmpty && bucket.graceRects.isEmpty) {
        emptyKeys.add(key);
      }
    });
    for (final key in emptyKeys) {
      _buckets.remove(key);
    }
  }

  /// Serializes the current state for the native request path. O(#fields) — no
  /// tree walk, so it stays cheap even while the main isolate is busy building a
  /// screen.
  ///
  /// Each live adapter's bounds are re-resolved first, exactly as the wrapper
  /// entries are in `OcclusionRegistry._handleCachedRectsRequest`. Serving the
  /// stored window alone meant a capture landing between two tier-1 refreshes was
  /// answered with geometry up to `_boundsIntervalMs` old: on the first frame of a
  /// fling every mask on screen sat a full scroll step behind the fields, and no
  /// amount of velocity projection could recover it because every sample in the
  /// window predated the motion. One ancestor walk per field per capture, and
  /// captures arrive a couple of times a second.
  List<Map<String, dynamic>> serializeRects(OcclusionRectCodec codec) {
    final nowMs = _clock();
    final rects = <Map<String, dynamic>>[];
    for (final bucket in _buckets.values) {
      for (final adapter in bucket.adapters.values) {
        if (!adapter.attached || !adapter.hasSize) continue;
        adapter.recalculateBounds();
        final bounds = adapter.getUnionOfHistoricalBounds();
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }
        rects.add(codec.encode(adapter.stableId, bounds,
            adapter.devicePixelRatio, OcclusionType.overlay));
      }
      for (final grace in bucket.graceRects) {
        if (grace.expiresAtMs <= nowMs) continue;
        rects.add(codec.encode(grace.id, grace.bounds, grace.devicePixelRatio,
            OcclusionType.overlay));
      }
    }
    return rects;
  }

  /// Drops everything immediately — used when the effective policy turns off so
  /// stale masks never outlive the decision.
  void clear() {
    _buckets.clear();
    _adapterScreen.clear();
  }

  /// Clears every adapter's sliding window (metrics change: keyboard/rotation).
  void clearSlidingWindows() {
    for (final bucket in _buckets.values) {
      for (final adapter in bucket.adapters.values) {
        adapter.clearHistoricalBounds();
      }
    }
  }
}

class _ScreenBucket {
  final Map<int, TextFieldOccludeRenderBox> adapters = {};
  final List<_GraceRect> graceRects = [];
}

class _GraceRect {
  const _GraceRect({
    required this.id,
    required this.bounds,
    required this.devicePixelRatio,
    required this.expiresAtMs,
  });

  final int id;
  final Rect bounds;
  final double devicePixelRatio;
  final int expiresAtMs;
}
