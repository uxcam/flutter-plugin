import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../internal/monotonic_clock.dart';
import 'occlusion_geometry.dart';
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

  static int _wallClock() => monotonicNowMs();

  /// How long a detached field's last bounds keep being served.
  static const int graceTtlMs = 500;

  final int Function() _clock;

  /// Adapter bounds resolves performed by this store — on creation and on
  /// cadence. Test-visible; the profiler holds the reported copy.
  @visibleForTesting
  int debugBoundsResolveCount = 0;

  /// Scratch lists reused across frames, so the per-frame detach bookkeeping
  /// allocates nothing. `Map.removeWhere` would allocate a key list and do a
  /// second lookup per entry on every frame.
  final List<int> _prunedIds = <int>[];
  final List<String> _emptyBucketKeys = <String>[];

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
    beginGeometryPass();
    try {
      for (final field in discovered.values) {
        final id = TextFieldOccludeRenderBox.stableIdFor(field.box);
        final existingKey = _adapterScreen[id];
        if (existingKey != null &&
            (_buckets[existingKey]?.adapters.containsKey(id) ?? false)) {
          continue; // known field — keep original attribution
        }
        final bucket = _buckets.putIfAbsent(
            activeScreenKey, () => _ScreenBucket(activeScreenKey));
        final adapter = TextFieldOccludeRenderBox(
          field.box,
          addPadding: field.isBareEditable,
          clock: _clock,
        );
        bucket.adapters[id] = adapter;
        _adapterScreen[id] = activeScreenKey;
        // A new field has bounds from its first frame without the whole store
        // refreshing: resolve this adapter alone, inside the pass the batch
        // shares. Fields already known keep to the refresh cadence.
        adapter.updateBoundsFromTransform();
        debugBoundsResolveCount++;
      }
    } finally {
      endGeometryPass();
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
    // One geometry pass for the whole batch: the fields share almost their
    // entire ancestor chain, so it is resolved once rather than once per field.
    beginGeometryPass();
    try {
      for (final bucket in _buckets.values) {
        _prunedIds.clear();
        for (final adapter in bucket.adapters.values) {
          if (!adapter.attached || !adapter.hasSize) {
            final last = adapter.getUnionOfHistoricalBounds();
            if (last != null && last.width > 0 && last.height > 0) {
              bucket.graceRects.add(_GraceRect(
                id: adapter.stableId,
                bounds: last,
                devicePixelRatio: adapter.devicePixelRatio,
                expiresAtMs: nowMs + graceTtlMs,
              ));
            }
            _prunedIds.add(adapter.stableId);
            continue;
          }
          if (refreshBounds) {
            adapter.updateBoundsFromTransform();
            debugBoundsResolveCount++;
          }
        }
        for (final id in _prunedIds) {
          bucket.adapters.remove(id);
          _adapterScreen.remove(id);
        }
        _expireGrace(bucket.graceRects, nowMs);
        if (bucket.adapters.isEmpty && bucket.graceRects.isEmpty) {
          _emptyBucketKeys.add(bucket.key);
        }
      }
    } finally {
      endGeometryPass();
    }
    if (_emptyBucketKeys.isNotEmpty) {
      for (final key in _emptyBucketKeys) {
        _buckets.remove(key);
      }
      _emptyBucketKeys.clear();
    }
  }

  /// Grace rects are appended as fields detach, so their expiries are in
  /// non-decreasing order and the expired ones form a prefix.
  static void _expireGrace(List<_GraceRect> graceRects, int nowMs) {
    var expired = 0;
    while (expired < graceRects.length &&
        graceRects[expired].expiresAtMs <= nowMs) {
      expired++;
    }
    if (expired > 0) graceRects.removeRange(0, expired);
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
  ///
  /// [coherent] is a property of the *capture*, not the store: it is set only when
  /// Flutter itself rasterised the pixels from the same committed frame these rects
  /// are resolved from (`requestSceneFrame` with pixels). Then the exact rect is
  /// served with no window union or motion margin, and detach grace is dropped — a
  /// field absent from the tree is absent from those pixels too, so serving its
  /// last position would mask a region the frame no longer shows. Every other
  /// capture screenshots natively a hop later, so it gets the widened rects and the
  /// grace ghosts that cover the gap.
  ///
  /// [coveredBy] lists the overlay rects already in this response — the
  /// `OccludeWrapper` entries — in the same logical coordinates. A text-field
  /// rect that lies entirely inside one of them is dropped: the region is filled
  /// by the wrapper's rect regardless, so the mask is identical and the field is
  /// not encoded, transported and filled twice. Only overlay wrappers qualify;
  /// a blur would change what the region looks like.
  List<Map<String, dynamic>> serializeRects(OcclusionRectCodec codec,
      {bool coherent = false, List<Rect> coveredBy = const <Rect>[]}) {
    final nowMs = _clock();
    final rects = <Map<String, dynamic>>[];
    beginGeometryPass();
    try {
      for (final bucket in _buckets.values) {
        for (final adapter in bucket.adapters.values) {
          if (!adapter.attached || !adapter.hasSize) continue;
          adapter.recalculateBounds();
          final bounds =
              adapter.getUnionOfHistoricalBounds(coherent: coherent);
          if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
            continue;
          }
          if (_isCovered(bounds, coveredBy)) {
            continue;
          }
          rects.add(codec.encode(adapter.stableId, bounds,
              adapter.devicePixelRatio, OcclusionType.overlay));
        }
        if (coherent) continue;
        for (final grace in bucket.graceRects) {
          if (grace.expiresAtMs <= nowMs) continue;
          if (_isCovered(grace.bounds, coveredBy)) {
            continue;
          }
          rects.add(codec.encode(grace.id, grace.bounds,
              grace.devicePixelRatio, OcclusionType.overlay));
        }
      }
    } finally {
      endGeometryPass();
    }
    return rects;
  }

  /// Whether [bounds] lies entirely inside one of [covers]. Plain containment:
  /// the codecs truncate or round every edge the same way, so containment in
  /// logical space survives encoding.
  static bool _isCovered(Rect bounds, List<Rect> covers) {
    for (final cover in covers) {
      if (cover.left <= bounds.left &&
          cover.top <= bounds.top &&
          cover.right >= bounds.right &&
          cover.bottom >= bounds.bottom) {
        return true;
      }
    }
    return false;
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
  _ScreenBucket(this.key);

  /// The screen this bucket belongs to — carried here so the per-frame walk can
  /// iterate values without materialising map entries.
  final String key;
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
