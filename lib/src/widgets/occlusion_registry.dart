import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/motion_reporter.dart';
import 'occlusion_models.dart';
import 'focus_tree_detector.dart';
import 'occlusion_rect_codec.dart';
import 'textfield_detector.dart';
import 'textfield_occlusion_policy.dart';
import 'textfield_rect_store.dart';

double _scenePixelRatioForTarget({
  required Size logicalSize,
  required double devicePixelRatio,
  double? targetWidth,
}) {
  if (targetWidth == null || targetWidth <= 0) return devicePixelRatio;
  return (targetWidth / logicalSize.width)
      .clamp(0.05, devicePixelRatio)
      .toDouble();
}

/// Coordinates the two occlusion domains and their native transport:
///
///  * **Wrapper/config occlusion** — `OccludeRenderBox` widgets and
///    config-driven overlay/blur rects, tracked in [_entries].
///  * **Auto text-field occlusion** — driven by [TextFieldOcclusionPolicy]
///    (API + native-pushed config), discovered by a [TextFieldDetector], and
///    held/served by a [TextFieldRectStore].
///
/// The registry itself owns only the method-channel endpoints, the frame
/// scheduling and the wrapper-entry lifecycle.
///
/// Text-field bounds are always sampled ahead of the request — tier-1 bounds
/// refresh every produced frame, tier-2 discovery walks bounded to
/// [_discoveryIntervalMs] or forced on screen/metrics/focus/policy changes, with
/// a sliding window and motion margin covering the gap between the last sample and
/// the screenshot.
///
/// Whether a served rect is *widened* from that window or handed back exact is
/// decided per capture request, not per platform (see `serializeRects`'s
/// `coherent` flag): a `requestSceneFrame` capture whose pixels Flutter itself
/// rasterised is coherent — the rects describe exactly those pixels, so no
/// widening is applied. A native-screenshot capture (`requestAllOcclusionRects`,
/// or a scene frame Flutter did not supply pixels for) screenshots a hop later, so
/// its rects are widened to survive the gap. The current iOS SDK screenshots
/// natively, so it takes the widened path today; the coherent path activates for
/// it the moment it drives capture end-to-end from Flutter.
class OcclusionRegistry with WidgetsBindingObserver {
  OcclusionRegistry._() {
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannelHandler();
    _setupPersistentFrameCallback();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  /// A route or dialog appearing takes focus, and that lands one frame earlier
  /// than the [_discoveryIntervalMs] throttle would otherwise allow discovery to
  /// run — which is the difference between masking a dialog's field from its
  /// first painted frame and leaving it exposed for the first three.
  ///
  /// Cheap to honour: the focus tree is what the detector walks anyway, and the
  /// forced-discovery counter is idempotent. Skipped entirely when the feature is
  /// off, so a focus change never wakes the engine for nothing.
  void _onFocusChanged() {
    if (_effectiveTextFields) _armForcedDiscovery();
  }

  static final OcclusionRegistry instance = OcclusionRegistry._();

  static const _detachedTtlMs = 1500;

  /// Minimum interval between full render-tree discovery walks (tier-2).
  /// Discovery is forced on the next frame after screen changes, metrics changes,
  /// focus changes (a route or dialog appearing takes focus) and policy
  /// enablement, so a brand-new field is still found in its first painted frame.
  static const _discoveryIntervalMs = 48;

  /// A one-shot force is not enough: on the frame after a push the incoming route
  /// is mid-build and its fields are not in the tree yet.
  static const _forceDiscoveryFrameCount = 4;

  /// Its only consumer is the 100 ms sliding-window union, which needs a handful of
  /// samples rather than one per frame. Kept well below that window and the 500 ms
  /// detach grace so neither loses resolution.
  static const _boundsIntervalMs = 33;

  Timer? _metricsChangeTimer;
  bool _metricsChanging = false;

  final TextFieldOcclusionPolicy _policy = TextFieldOcclusionPolicy();

  /// Lever 4: sourced from the focus tree rather than the render tree. Swapping
  /// this line is the whole change — the registry never needed to know which
  /// detector it holds, which is what the [TextFieldDetector] abstraction was for.
  final TextFieldDetector _detector = FocusTreeDetector();
  final OcclusionRectCodec _codec = OcclusionRectCodec();
  TextFieldRectStore _textFieldStore = TextFieldRectStore();

  /// Snapshot of `_policy.effective` so transitions (on→off) can clear the
  /// store exactly once.
  bool _effectiveTextFields = false;

  int _forceDiscoveryFrames = 0;
  int _lastDiscoveryMs = 0;
  int _lastBoundsMs = 0;

  /// Injectable so tests can drive the cadences, which are in real milliseconds
  /// while `tester.pump` advances only the test clock.
  int Function() _clock = _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  /// Reused across scans to avoid per-frame map allocation during animations.
  final Map<int, DiscoveredField> _discoveredBuffer = {};

  /// Common occlusion — the wrapper-widget (`OccludeRenderBox`) and
  /// config-driven overlay/blur rects.
  final Map<int, _OcclusionEntry> _entries = {};

  static const MethodChannel _requestChannel =
      MethodChannel('uxcam_occlusion_request');

  static const MethodChannel _requestChannelIOS =
      MethodChannel('flutter_uxcam');

  /// Manual API switch (`FlutterUxcam.occludeAllTextFields`). One of three
  /// additive sources: it switches masking on, and cannot switch off what the
  /// verification configuration or the native per-capture value asks for —
  /// matching both native SDKs, where no source can reduce another's occlusion.
  set occludeAllTextFields(bool value) {
    _policy.manualBase = value;
    _onPolicyChanged();
  }

  /// Drops the verification/dashboard layer so a statement from a finished
  /// session cannot keep masking a later one. The registry is a process-wide
  /// singleton, so nothing else expires it. Called from
  /// `FlutterUxcam.startWithConfiguration`.
  ///
  /// The manual layer is deliberately preserved: the developer's call survives a
  /// session restart, as it does natively.
  void resetConfigurationLayer() {
    if (_policy.clearConfiguration()) _onPolicyChanged();
  }

  /// The current screen name, sourced from Flutter (automatic route tagging via
  /// `FlutterUxcamNavigatorObserver`, or manual `FlutterUxcam.tagScreenName`).
  /// Drives the per-screen exclusion rules and the per-screen bucketing.
  set currentScreenName(String? value) {
    if (_policy.currentScreen == value) return;
    _policy.currentScreen = value;
    _armForcedDiscovery();
    _onPolicyChanged();
  }

  String get _activeScreenKey => _policy.currentScreen ?? '__uxcam_current__';

  /// Requests a frame as well as arming the counter: on a settled screen Flutter
  /// produces no frames, so a forced discovery would otherwise never run.
  void _armForcedDiscovery() {
    _forceDiscoveryFrames = _forceDiscoveryFrameCount;
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Re-evaluates the effective decision after any policy input changed. When
  /// occlusion turns off (disabled, or navigated to an excluded screen), the
  /// held rects are dropped immediately so stale masks never outlive the
  /// decision; when it turns on, discovery is forced onto the next frame.
  void _onPolicyChanged() {
    final effective = _policy.effective;
    if (_effectiveTextFields && !effective) {
      _textFieldStore.clear();
    } else if (!_effectiveTextFields && effective) {
      _armForcedDiscovery();
    }
    _effectiveTextFields = effective;
  }

  /// Keyboard show/hide, rotation and window resize all fire here. Layout takes
  /// a few frames to settle, during which per-frame bounds would jump around,
  /// so wrapper occlusion freezes to its last-known bounds for a short window.
  /// Text-field discovery is *forced* instead of frozen — see [_onFrame].
  @override
  void didChangeMetrics() {
    _metricsChanging = true;
    _metricsChangeTimer?.cancel();
    _clearSlidingWindows();
    _armForcedDiscovery();
    _metricsChangeTimer = Timer(const Duration(milliseconds: 500), () {
      _metricsChanging = false;
    });
  }

  void _setupMethodChannelHandler() {
    _requestChannel.setMethodCallHandler(_handleMethodCall);
    if (!kIsWeb) {
      _requestChannelIOS.setMethodCallHandler(_handleMethodCall);
    }
  }

  List<Map<String, dynamic>> getOcclusionRects() => _handleCachedRectsRequest();

  void _setupPersistentFrameCallback() {
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  bool _discover(int nowMs) {
    final views = WidgetsBinding.instance.renderViews;
    if (views.isEmpty) return false;

    if (_forceDiscoveryFrames > 0) _forceDiscoveryFrames--;
    _lastDiscoveryMs = nowMs;
    _discoveredBuffer.clear();
    _detector.collect(views.first, _discoveredBuffer);
    _textFieldStore.reconcile(_activeScreenKey, _discoveredBuffer);
    return true;
  }

  /// Discovers unconditionally before answering a capture, so the served set can
  /// never be a screen behind the tree.
  ///
  /// Frame-driven discovery is throttled to [_discoveryIntervalMs] and only runs
  /// when Flutter produces a frame at all, so both paths can leave the store
  /// stale at the instant that matters. During a fling, list items build as they
  /// scroll in: a field that appeared since the last scan had no adapter, and the
  /// only rects on offer were the detach-grace ghosts of the items it replaced —
  /// masks sitting a full scroll step behind, on every field on screen. Nothing
  /// downstream could recover that; the field simply was not being tracked.
  ///
  /// Affordable because discovery walks the focus tree rather than the render
  /// tree (see [FocusTreeDetector]) — a handful of nodes per field — and captures
  /// arrive a couple of times a second, not at frame rate.
  void _discoverForCapture() {
    if (!_effectiveTextFields) return;
    final nowMs = _clock();
    if (!_discover(nowMs)) return;
    _lastBoundsMs = nowMs;
    // Detach bookkeeping only: `serializeRects` re-resolves each live adapter's
    // bounds itself, so resolving them here too would walk every field's ancestor
    // chain twice per capture.
    _textFieldStore.updateBounds(refreshBounds: false);
  }

  /// Wrapper/config occlusion freezes its bounds updates while window metrics
  /// settle (keyboard show/hide, rotation) to avoid jitter — it keeps serving
  /// its last-known bounds from cache during the freeze.
  void _refreshWrapperEntries() {
    if (_metricsChanging) return;
    for (final entry in _entries.values.toList()) {
      final box = entry.box;
      if (entry.attached && box != null && box.attached && box.hasSize) {
        box.updateBoundsFromTransform();
        _refreshEntryFromBox(entry, box);
      }
    }
  }

  void _onFrame(Duration timestamp) {
    if (_entries.isEmpty && !_effectiveTextFields && _textFieldStore.isEmpty) {
      return;
    }

    _refreshWrapperEntries();

    // Text-field pipeline. Discovery must NOT pause during a metrics change: a
    // screen that auto-focuses a field brings up the keyboard at the very
    // instant it appears, so a freeze would leave that brand-new field unmasked
    // for the whole settling window. The mask simply tracks the field as the
    // keyboard animates, which is the safe behavior for a privacy overlay.
    final nowMs = _clock();
    var discovered = false;

    if (_effectiveTextFields &&
        (_forceDiscoveryFrames > 0 ||
            nowMs - _lastDiscoveryMs >= _discoveryIntervalMs)) {
      discovered = _discover(nowMs);
    }

    // Detach bookkeeping runs every frame; only the expensive chain resolution is
    // throttled. Discovery frames always refresh so a new field is never left
    // without bounds.
    final refreshBounds =
        discovered || nowMs - _lastBoundsMs >= _boundsIntervalMs;
    if (refreshBounds) {
      _lastBoundsMs = nowMs;
    }

    _textFieldStore.updateBounds(refreshBounds: refreshBounds);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestOcclusionRects':
      case 'requestAllOcclusionRects': //Currently iOS only
        _applyNativeOcclusionSettings(call.arguments);
        _markNativeRecordingRequested();
        return _handleCachedRectsRequest();
      case 'requestSceneFrame': //Currently iOS only
        _applyNativeOcclusionSettings(call.arguments);
        _markNativeRecordingRequested();
        return _handleSceneFrameRequest(call.arguments);
      case 'updateOcclusionConfiguration':
        // Pushed by native (over the existing bridge channel — no public API)
        // when the session verification resolves or the occlusion config
        // changes. Establishes the text-field occlusion state in Flutter memory
        // as early as possible, so the first screen with text fields is already
        // being scanned instead of waiting for the first capture cycle. This is
        // the CONFIG layer, which carries the dashboard's screen scope as well as
        // the flag. Android sends it; iOS does not, so there a verification
        // response reaches Flutter only through the per-capture flag on the three
        // capture methods above (see `TextFieldOcclusionPolicy`).
        _applyNativeOcclusionSettings(call.arguments, isConfigSource: true);
        return true;
      default:
        throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'Method ${call.method} not supported',
        );
    }
  }

  Future<Map<String, dynamic>> _handleSceneFrameRequest(
      dynamic arguments) async {
    final args = arguments is Map ? arguments : const <String, Object?>{};
    final targetWidth = (args['targetWidth'] as num?)?.toDouble();
    final includePixels = args['includePixels'] != false;

    final renderViews = RendererBinding.instance.renderViews;
    final RenderView? renderView =
        renderViews.isEmpty ? null : renderViews.first;

    final logicalSize =
        renderView?.hasConfiguration == true ? renderView!.size : Size.zero;

    // Decide *synchronously*, before the rects are resolved, whether Flutter
    // itself will supply the pixels for this capture. Only then are the rects
    // coherent with them: the SDK rasterises the raster we return instead of
    // screenshotting natively a hop later. Every check that can veto the raster is
    // made up front so the `coherent` flag we stamp the rects with matches what
    // actually ships — a rect stamped coherent but paired with a native screenshot
    // is exactly the un-widened, lagging mask this path must not emit.
    // ignore: invalid_use_of_protected_member
    final layer = renderView?.layer;
    final rootLayer = layer is OffsetLayer ? layer : null;
    final dpr = renderView?.flutterView.devicePixelRatio ?? 0;
    final canProvidePixels = includePixels &&
        renderView != null &&
        !logicalSize.isEmpty &&
        rootLayer != null &&
        rootLayer.attached &&
        !_containsPlatformViewLayer(rootLayer) &&
        dpr > 0;

    // LOAD-BEARING ORDER: the rects are resolved here, synchronously, and the
    // root layer is rasterised below with no `await` in between. Dart is
    // single-threaded and a frame cannot be produced inside that gap, so both
    // read the same committed frame and the rects describe exactly these pixels.
    // That equality is what lets a coherent capture drop the sliding window and
    // the motion margin. Do not introduce an `await` between this line and
    // `toImage`, and do not hoist the rects to a cache filled earlier — either
    // reinstates the staleness those mechanisms existed to hide, with nothing
    // left to hide it.
    final response = <String, dynamic>{
      'rects': _handleCachedRectsRequest(coherent: canProvidePixels),
      'coordinateSpace': 'sourceLogicalPoints',
      if (!logicalSize.isEmpty) ...{
        'referenceWidth': logicalSize.width,
        'referenceHeight': logicalSize.height,
      },
    };

    if (!canProvidePixels) return response;

    try {
      final scale = _scenePixelRatioForTarget(
        logicalSize: logicalSize,
        devicePixelRatio: dpr,
        targetWidth: targetWidth,
      );
      final image = await rootLayer.toImage(
        Offset.zero & (logicalSize * dpr),
        pixelRatio: scale / dpr,
      );
      try {
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData == null) return response;
        response.addAll(<String, dynamic>{
          'bytes': byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          'pixelWidth': image.width,
          'pixelHeight': image.height,
          'logicalWidth': logicalSize.width,
          'logicalHeight': logicalSize.height,
        });
      } finally {
        image.dispose();
      }
    } catch (_) {}
    return response;
  }

  bool _containsPlatformViewLayer(Layer layer) {
    if (layer is PlatformViewLayer) return true;
    if (layer is ContainerLayer) {
      for (Layer? child = layer.firstChild;
          child != null;
          child = child.nextSibling) {
        if (_containsPlatformViewLayer(child)) return true;
      }
    }
    return false;
  }

  void _applyNativeOcclusionSettings(dynamic arguments,
      {bool isConfigSource = false}) {
    if (_policy.applyNativeSettings(arguments,
        isConfigSource: isConfigSource)) {
      _onPolicyChanged();
    }
  }

  /// Every capture request is proof the native side is still recording, which is
  /// what re-arms [MotionReporter]'s idle timeout.
  ///
  /// Not iOS-only: `FlutterUxcam.startWithConfiguration` now starts the reporter
  /// on Android too, and without a re-arm here its 5 s idle timeout would detach
  /// the pointer route on the first quiet stretch and end motion reporting for
  /// the rest of the session. Android's `requestOcclusionRects` and
  /// `requestSceneFrame` arrive per capture, exactly as iOS's do.
  void _markNativeRecordingRequested() {
    if (!kIsWeb) {
      MotionReporter.instance.markRecordingRequested();
    }
  }

  /// [coherent] is passed through to the text-field store: `true` only for a
  /// capture whose pixels Flutter itself rasterised (`requestSceneFrame` with
  /// pixels), where the exact rect describes the pixels; `false` — the default,
  /// and what `requestAllOcclusionRects` / `requestOcclusionRects` and
  /// [getOcclusionRects] use — widens each rect to survive the native-screenshot
  /// hop. The wrapper/config entries below are unaffected: they carry their own
  /// window and are served the same way on either path.
  List<Map<String, dynamic>> _handleCachedRectsRequest({bool coherent = false}) {
    _discoverForCapture();

    final requestTimestamp = _clock();

    _expireStaleEntries(requestTimestamp);

    final rects = <Map<String, dynamic>>[];
    final snapshot = _entries.values.toList();

    for (final entry in snapshot) {
      if (_metricsChanging) {
        final bounds = entry.lastBounds;
        if (bounds != null && bounds.width > 0 && bounds.height > 0) {
          rects.add(_rectDataFromEntry(entry, bounds));
        }
        continue;
      }
      if (entry.attached) {
        final box = entry.box;
        if (box == null || !box.attached || !box.hasSize) {
          final canUseCache = entry.lastBounds != null &&
              (requestTimestamp - entry.lastUpdatedMs) <= _detachedTtlMs;
          if (canUseCache) {
            rects.add(_rectDataFromEntry(entry, entry.lastBounds!));
          }
          continue;
        }

        box.updateBoundsFromTransform();

        final bounds = box.getUnionOfHistoricalBounds();
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }

        _refreshEntryFromBox(entry, box, overrideBounds: bounds);
        rects.add(_rectDataFromEntry(entry, bounds));
      } else {
        final bounds = entry.lastBounds;
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }
        rects.add(_rectDataFromEntry(entry, bounds));
      }
    }

    // Append the auto text-field rects: live adapter state + short-grace ghosts
    // serialized on the spot — O(#fields), no tree walk or layout work, so the
    // request path stays cheap even while the main isolate is busy building a
    // screen (which is when the native request would otherwise time out and
    // emit an unmasked frame).
    rects.addAll(_textFieldStore.serializeRects(_codec, coherent: coherent));

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
      ..lastUpdatedMs = _clock()
      ..devicePixelRatio = box.devicePixelRatio
      ..viewId = box.viewId
      ..type = box.currentType;
  }

  void remove(OcclusionReportingRenderBox box) {
    _entries.remove(box.stableId);
  }

  void _clearSlidingWindows() {
    for (final entry in _entries.values) {
      entry.box?.clearHistoricalBounds();
    }
    _textFieldStore.clearSlidingWindows();
  }

  void _refreshEntryFromBox(
    _OcclusionEntry entry,
    OcclusionReportingRenderBox box, {
    Rect? overrideBounds,
  }) {
    final now = _clock();
    final newBounds = overrideBounds ?? box.currentBounds;
    entry
      ..lastBounds = newBounds ?? entry.lastBounds
      ..lastUpdatedMs = now
      ..devicePixelRatio = box.devicePixelRatio
      ..viewId = box.viewId
      ..type = box.currentType;
  }

  Map<String, dynamic> _rectDataFromEntry(_OcclusionEntry entry, Rect bounds) =>
      _codec.encode(entry.id, bounds, entry.devicePixelRatio ?? 1.0,
          entry.type ?? OcclusionType.overlay);

  void _expireStaleEntries(int nowMs) {
    _entries.removeWhere(
      (_, entry) =>
          !entry.attached && (nowMs - entry.lastUpdatedMs) > _detachedTtlMs,
    );
  }

  /// Replaces the text-field store (e.g. with an injected fake clock) so
  /// widget tests can control grace expiry deterministically.
  @visibleForTesting
  void debugReplaceTextFieldStore(TextFieldRectStore store) {
    _textFieldStore = store;
  }

  @visibleForTesting
  TextFieldOcclusionPolicy get debugTextFieldPolicy => _policy;

  /// Overrides the wall clock so tests can drive the discovery and bounds
  /// cadences deterministically.
  @visibleForTesting
  void debugSetClock(int Function() clock) => _clock = clock;

  /// Serves the text-field rects exactly as a capture would, letting a test pick
  /// the per-request coherence: `coherent: true` mirrors a `requestSceneFrame`
  /// whose pixels Flutter rasterised (exact rects, no window/margin/grace);
  /// `coherent: false` mirrors a native-screenshot capture
  /// (`requestAllOcclusionRects`) and is what [getOcclusionRects] serves.
  @visibleForTesting
  List<Map<String, dynamic>> debugServeRects({bool coherent = false}) =>
      _handleCachedRectsRequest(coherent: coherent);

  /// The live store, so a test can tell "discovery has not run" apart from
  /// "discovery ran and found nothing".
  @visibleForTesting
  TextFieldRectStore get debugTextFieldStore => _textFieldStore;

  /// Resets the auto text-field state between tests. The registry is a
  /// singleton, so without this, policy/store state leaks across test cases.
  @visibleForTesting
  void resetTextFieldStateForTesting() {
    _policy
      ..manualBase = null
      ..configBase = null
      ..frameBase = null
      ..screens = const []
      ..excludeMentionedScreens = false
      ..currentScreen = null;
    _effectiveTextFields = false;
    _forceDiscoveryFrames = 0;
    _lastDiscoveryMs = 0;
    _textFieldStore = TextFieldRectStore();
    _discoveredBuffer.clear();
    _lastBoundsMs = 0;
    _clock = _wallClock;
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
