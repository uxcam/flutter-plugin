import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/monotonic_clock.dart';
import '../internal/motion_reporter.dart';
import 'occlusion_geometry.dart';
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
/// Every capture discovers and re-resolves bounds before answering, so *what*
/// gets masked never depends on the frame pipeline. The frame pipeline — tier-1
/// bounds sampling, tier-2 discovery on a [_discoveryIntervalMs] cadence or
/// forced on screen/metrics/focus/policy changes, the sliding window and the
/// motion margin — exists to cover the gap between the last sample and a
/// screenshot taken natively a hop later.
///
/// Whether a served rect is *widened* from that window or handed back exact is
/// decided per capture request, not per platform (see `serializeRects`'s
/// `coherent` flag): a `requestSceneFrame` capture whose pixels Flutter itself
/// rasterised is coherent — the rects describe exactly those pixels, so no
/// widening is applied and none of the history is read. A native-screenshot
/// capture (`requestAllOcclusionRects`, `requestOcclusionRects`, or a scene
/// frame Flutter did not supply pixels for) is widened to survive the gap.
///
/// Because a coherent capture reads none of the pipeline's output, the pipeline
/// only runs while a native-screenshot capture is possible — the keyboard is up,
/// window metrics are settling, or the last capture was one (see
/// [_nonCoherentPossible]). Otherwise a frame does detach bookkeeping and nothing
/// else. On the transition into that regime the sliding windows are cleared,
/// which stamps every field unknown-velocity so the first widened capture is
/// served inflated while history re-accumulates — the same mechanism a keyboard
/// slide already relies on.
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

  /// Window metrics (keyboard, rotation, resize) count as settling for this
  /// long after the last change.
  static const _metricsSettleMs = 500;

  /// End of the current settling window on [_clock], or 0. Read lazily rather
  /// than flipped by a timer, so a metrics event allocates nothing and there is
  /// no pending timer to lose.
  int _metricsSettleDeadlineMs = 0;

  bool get _metricsChanging => _clock() < _metricsSettleDeadlineMs;

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

  /// Whether the frame pipeline is running (true) or gated to detach
  /// bookkeeping only (false). Kept in step with [_nonCoherentPossible] by
  /// [_updatePipelineGate].
  bool _pipelineActive = false;

  /// The regime of the most recent capture: true when it was served to a native
  /// screenshot (a rects-only request, or a scene frame Flutter could not supply
  /// pixels for); false once a coherent scene capture has been served. Native
  /// decides this per capture, so the pipeline can only stop when native says
  /// the coherent path is back — never prematurely.
  bool _lastCaptureNonCoherent = false;

  /// Frames on which the text-field pipeline ran, and frames it skipped because
  /// the gate was closed. Test-visible; the profiler holds the reported copies.
  @visibleForTesting
  int debugPipelineFrameCount = 0;
  @visibleForTesting
  int debugGatedFrameCount = 0;
  @visibleForTesting
  int debugForcedArmCount = 0;
  @visibleForTesting
  int debugDiscoveryWalkCount = 0;
  @visibleForTesting
  int debugWindowClearCount = 0;

  @visibleForTesting
  bool get debugPipelineActive => _pipelineActive;

  /// Whether a capture served in the current state could be a native screenshot,
  /// so the frame pipeline's history would be read.
  ///
  /// The keyboard is read from the view insets, which Dart sees on the same
  /// frame the keyboard starts to move — native's own `keyboardVisible` veto
  /// would only be seen a capture later.
  bool get _nonCoherentPossible =>
      _metricsChanging || _lastCaptureNonCoherent || _keyboardVisible;

  bool get _keyboardVisible {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView;
    if (view != null) return view.viewInsets.bottom > 0;
    for (final other in dispatcher.views) {
      if (other.viewInsets.bottom > 0) return true;
    }
    return false;
  }

  /// Brings [_pipelineActive] in line with [_nonCoherentPossible]. Returns true
  /// when the gate just opened: that transition clears the sliding windows —
  /// stamping every field unknown-velocity so the next widened serve is inflated
  /// while history re-accumulates — and arms discovery, exactly as a metrics
  /// change does.
  bool _updatePipelineGate() {
    final shouldRun = _nonCoherentPossible;
    if (shouldRun == _pipelineActive) return false;
    _pipelineActive = shouldRun;
    if (!shouldRun) return false;
    _clearSlidingWindows();
    _armForcedDiscovery();
    return true;
  }

  /// Injectable so tests can drive the cadences, which are in real milliseconds
  /// while `tester.pump` advances only the test clock.
  int Function() _clock = _wallClock;

  static int _wallClock() => monotonicNowMs();

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

  /// Arms the counter and, while the pipeline is running, requests a frame: on a
  /// settled screen Flutter produces none, so a forced discovery would otherwise
  /// never run. While the gate is closed the capture path discovers on its own,
  /// so waking a settled screen would only cost a frame; the counter stays armed
  /// for the first frame after the gate opens.
  void _armForcedDiscovery() {
    debugForcedArmCount++;
    _forceDiscoveryFrames = _forceDiscoveryFrameCount;
    if (_pipelineActive) {
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  /// Re-evaluates the effective decision after any policy input changed. When
  /// occlusion turns off (disabled, or navigated to an excluded screen), the
  /// held rects are dropped immediately so stale masks never outlive the
  /// decision; when it turns on, discovery is forced onto the next frame.
  void _onPolicyChanged() {
    final effective = _policy.effective;
    if (_effectiveTextFields && !effective) {
      // Release everything the feature holds, not just the served rects: the
      // detector's memo and the discovery buffer both pin render subtrees, and
      // a feature that is off must not keep them alive.
      _textFieldStore.clear();
      _detector.reset();
      _discoveredBuffer.clear();
      _forceDiscoveryFrames = 0;
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
    final newEpisode = !_metricsChanging;
    _metricsSettleDeadlineMs = _clock() + _metricsSettleMs;
    // The first event of an episode opens the gate if it was closed, and that
    // transition clears and arms. Otherwise: the clear runs on every event — it
    // is what keeps the unknown-velocity inflate armed while the fields slide —
    // but discovery is armed once per episode. A keyboard animation delivers a
    // metrics change on every frame, and re-arming four forced walks on each one
    // ran discovery on every frame of the animation. Discovery keeps its cadence
    // through the rest of the episode, and every capture discovers on its own.
    if (!_updatePipelineGate()) {
      _clearSlidingWindows();
      if (newEpisode) _armForcedDiscovery();
    }
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

    debugDiscoveryWalkCount++;
    if (_forceDiscoveryFrames > 0) {
      _forceDiscoveryFrames--;
    }
    _lastDiscoveryMs = nowMs;
    _discoveredBuffer.clear();
    _detector.collect(views.first, _discoveredBuffer);
    _textFieldStore.reconcile(_activeScreenKey, _discoveredBuffer);
    // The buffer is reused across scans so no map is allocated per walk, but
    // between walks it would otherwise pin the last scan's render boxes.
    _discoveredBuffer.clear();
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
    if (_entries.isEmpty || _metricsChanging) return;
    beginGeometryPass();
    try {
      // Nothing in the loop adds or removes entries, so the map is iterated in
      // place rather than snapshotted every frame.
      for (final entry in _entries.values) {
        final box = entry.box;
        if (entry.attached && box != null && box.attached && box.hasSize) {
          box.updateBoundsFromTransform();
          _refreshEntryFromBox(entry, box);
        }
      }
    } finally {
      endGeometryPass();
    }
  }

  void _onFrame(Duration timestamp) {
    if (_entries.isEmpty && !_effectiveTextFields && _textFieldStore.isEmpty) {
      return;
    }
    _onFrameWork();
  }

  void _onFrameWork() {
    _refreshWrapperEntries();

    if (!_effectiveTextFields) {
      // Off: only grace ghosts can be outstanding; let them expire.
      if (!_textFieldStore.isEmpty) {
        _textFieldStore.updateBounds(refreshBounds: false);
      }
      return;
    }

    _updatePipelineGate();
    if (!_pipelineActive) {
      // Coherent regime: the capture path discovers and resolves on its own and
      // reads none of the history, so only detach bookkeeping runs — it releases
      // a recycled row's adapter within a frame rather than holding it until the
      // next capture.
      debugGatedFrameCount++;
      _textFieldStore.updateBounds(refreshBounds: false);
      return;
    }

    // Text-field pipeline. Discovery must NOT pause during a metrics change: a
    // screen that auto-focuses a field brings up the keyboard at the very
    // instant it appears, so a freeze would leave that brand-new field unmasked
    // for the whole settling window. The mask simply tracks the field as the
    // keyboard animates, which is the safe behavior for a privacy overlay.
    debugPipelineFrameCount++;
    final nowMs = _clock();

    if (_forceDiscoveryFrames > 0 ||
        nowMs - _lastDiscoveryMs >= _discoveryIntervalMs) {
      _discover(nowMs);
    }

    // Detach bookkeeping runs every frame; only the expensive chain resolution is
    // throttled. A discovery frame does not force a refresh of every field:
    // `reconcile` resolves the adapters it creates on the spot, so a new field
    // still has bounds in its first frame while the fields already known keep to
    // the cadence. Coupling the two made a forced-discovery burst (a route push,
    // a keyboard slide) run both tiers at full frame rate together.
    final refreshBounds = nowMs - _lastBoundsMs >= _boundsIntervalMs;
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
        final rects = _handleCachedRectsRequest();
        return rects;
      case 'requestSceneFrame': //Currently iOS only
        // Spans the awaited raster too, so this probe is wall-clock; the
        // UI-thread share is `sceneRequestSync`.
        _applyNativeOcclusionSettings(call.arguments);
        _markNativeRecordingRequested();
        final response = await _handleSceneFrameRequest(call.arguments);
        return response;
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
        !_hasPlatformViewLayer(rootLayer) &&
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
    // Everything above ran synchronously on the UI thread; the raster below is
    // awaited and lands on the raster thread.

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

  bool _hasPlatformViewLayer(Layer root) {
    final found = _containsPlatformViewLayer(root);
    return found;
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
    // One geometry pass across the wrapper entries and the text-field store:
    // nothing between here and the return can change layout, so every resolve
    // in this capture shares the memoised ancestor chain.
    beginGeometryPass();
    final List<Map<String, dynamic>> rects;
    try {
      rects = _serveRects(coherent: coherent);
    } finally {
      endGeometryPass();
    }
    return rects;
  }

  List<Map<String, dynamic>> _serveRects({required bool coherent}) {
    // The regime this capture is in, applied before anything is resolved: a
    // rects-only request or a scene frame without Flutter pixels is served to a
    // native screenshot a hop later, so the frame pipeline must be running — and
    // when this is the capture that starts it, the clear inside the transition
    // inflates this very serve.
    _lastCaptureNonCoherent = !coherent;
    _updatePipelineGate();

    _discoverForCapture();

    final requestTimestamp = _clock();

    _expireStaleEntries(requestTimestamp);

    final rects = <Map<String, dynamic>>[];
    _overlayWrapperBounds.clear();

    /// Serves one wrapper rect and remembers it for the text-field dedupe when
    /// it is an opaque overlay.
    void serveWrapper(_OcclusionEntry entry, Rect bounds) {
      rects.add(_rectDataFromEntry(entry, bounds));
      if ((entry.type ?? OcclusionType.overlay) == OcclusionType.overlay) {
        _overlayWrapperBounds.add(bounds);
      }
    }

    // Stale entries were expired above and nothing below mutates the map.
    for (final entry in _entries.values) {
      if (_metricsChanging) {
        final bounds = entry.lastBounds;
        if (bounds != null && bounds.width > 0 && bounds.height > 0) {
          serveWrapper(entry, bounds);
        }
        continue;
      }
      if (entry.attached) {
        final box = entry.box;
        if (box == null || !box.attached || !box.hasSize) {
          final canUseCache = entry.lastBounds != null &&
              (requestTimestamp - entry.lastUpdatedMs) <= _detachedTtlMs;
          if (canUseCache) {
            serveWrapper(entry, entry.lastBounds!);
          }
          continue;
        }

        box.updateBoundsFromTransform();

        final bounds = box.getUnionOfHistoricalBounds();
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }

        _refreshEntryFromBox(entry, box, overrideBounds: bounds);
        serveWrapper(entry, bounds);
      } else {
        final bounds = entry.lastBounds;
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }
        serveWrapper(entry, bounds);
      }
    }

    // Append the auto text-field rects: live adapter state + short-grace ghosts
    // serialized on the spot — O(#fields), no tree walk or layout work, so the
    // request path stays cheap even while the main isolate is busy building a
    // screen (which is when the native request would otherwise time out and
    // emit an unmasked frame). A field sitting inside an overlay wrapper is
    // already covered by the wrapper's rect and is not sent twice.
    rects.addAll(_textFieldStore.serializeRects(_codec,
        coherent: coherent, coveredBy: _overlayWrapperBounds));

    return rects;
  }

  /// Overlay wrapper rects served in the current response, reused across
  /// captures so the dedupe allocates nothing.
  final List<Rect> _overlayWrapperBounds = <Rect>[];

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
    debugWindowClearCount++;
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

  /// The detector, so a test can pin what it remembers between scans.
  @visibleForTesting
  TextFieldDetector get debugDetector => _detector;

  /// Entries left in the reused discovery buffer between scans.
  @visibleForTesting
  int get debugDiscoveredBufferLength => _discoveredBuffer.length;

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
    _detector.reset();
    _discoveredBuffer.clear();
    _lastBoundsMs = 0;
    _clock = _wallClock;
    _pipelineActive = false;
    _lastCaptureNonCoherent = false;
    _metricsSettleDeadlineMs = 0;
    debugPipelineFrameCount = 0;
    debugGatedFrameCount = 0;
    debugForcedArmCount = 0;
    debugDiscoveryWalkCount = 0;
    debugWindowClearCount = 0;
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
