# Automatic TextField Occlusion

> Feature: occlude every `TextField` in a Flutter app automatically, without
> wrapping each field, driven by `FlutterUxcam.occludeAllTextFields(true)` **or**
> by dashboard/verification config pushed down from the native SDK.

**Change set** (branch `feature/auto-textfield-occlusion-android` in both repos):

| Repo | Base | What |
|------|------|------|
| Flutter plugin (`uxcam-flutter-plugin`) | `develop` | Dart focus-tree scan, native-settings handler, Android plugin forwarding |
| Android SDK (`android-sdk`) | `develop` | Resolves the effective flag and publishes it on the capture delegate |
| iOS SDK | — | Already pushes `occludeAllTextFields` on `requestSceneFrame` (pre-existing) |

---

## 1. Objective

Give apps a **single switch** that masks the content of *all* text input fields
in the recorded session, so sensitive user input (emails, names, card numbers,
OTPs, passwords) never reaches the UXCam dashboard — with **zero per-widget
work** from the integrator.

```dart
FlutterUxcam.startWithConfiguration(config);
FlutterUxcam.occludeAllTextFields(true); // that's it
```

---

## 2. Problem statement

UXCam records the screen by pulling **occlusion rectangles** from the Flutter
side and painting masks over them on the native recording. The existing system
is **widget-driven**: the integrator has to wrap every sensitive widget so an
`OccludeRenderBox` gets inserted into the render tree and registers itself with
the `OcclusionRegistry`.

That model has two gaps for text input:

1. **Coverage burden.** Every `TextField` must be wrapped by hand. One missed
   field leaks plaintext into the recording — a privacy/compliance risk.
2. **Native `occludeAllTextFields` doesn't help on Flutter.** The pre-existing
   `occludeAllTextFields` method only forwards to the native SDK. Native code
   masks *native* `UITextField` / `EditText` views — but Flutter draws its
   TextFields into its own surface, invisible to the native view hierarchy. So
   for a Flutter app the native call is effectively a no-op.

We need the "occlude all text fields" guarantee to be enforced **inside Flutter**,
where the fields actually live.

---

## 3. Solution (overview)

When the flag is on, a `TextFieldDetector` **walks the focus tree**, finds every
`RenderEditable` (the render object behind every `EditableText`, and therefore
every `TextField` / `TextFormField` / `CupertinoTextField`), and a
`TextFieldRectStore` holds a lightweight **adapter**
(`TextFieldOccludeRenderBox`) for each one. From that point the adapter
participates in the *exact same* occlusion pipeline as manually-wrapped widgets:
its bounds are resolved by the shared geometry pass and served to native on
request.

```
                        ┌──────────────────────────────┐
   occludeAllTextFields  │      OcclusionRegistry       │
   (true) ──────────────▶│  TextFieldOcclusionPolicy    │
   config push ─────────▶│        .effective == true    │
                         └──────────────┬───────────────┘
                                        │ tier-1 every frame · discovery ≤48ms
                                        ▼
                          FocusTreeDetector.collect()  ── walks focus tree
                                        │
              finds RenderEditable ─────┤
                                        ▼
             ┌───────────────────────────────────────────┐
             │  TextFieldOccludeRenderBox (adapter)      │
             │  wraps the InputDecorator decoration box  │
             │  (or the bare RenderEditable as fallback) │
             └──────────────────┬────────────────────────┘
                                │ reconcile()  (per-screen bucket)
                                ▼
                      TextFieldRectStore buckets
                                │
      native `requestOcclusionRects` ─▶ live rects + grace ─▶ mask on video
```

**Key design choice — decoupling.** Text-field discovery reuses the geometry
logic that widget occlusion already had (visibility + clip math), but rather
than making that logic public on `OccludeRenderBox`, it was extracted into a
standalone module (`occlusion_geometry.dart`) that both consumers import. The
feature is therefore **fully modular**: deleting the `textfield_*` files and the
registry's text-field wiring removes it without touching widget occlusion.

---

## 4. Solution — detailed analysis

### 4.1 Components

| File | Role |
|------|------|
| `lib/src/widgets/occlusion_geometry.dart` | **New.** `resolveOcclusionGeometry()` — visibility, global transform and accumulated clip in a *single* ancestor pass, plus the per-type visibility checkers (`RenderIndexedStack`, `RenderViewport`). Consumed by both render boxes. |
| `lib/src/widgets/textfield_detector.dart` | **New.** `TextFieldDetector` interface, the `DiscoveredField` value type, the decorator climb (`findDecoratorAncestor`), and `RenderEditableDetector` — the complete-by-construction render-tree walk kept as the parity reference. |
| `lib/src/widgets/focus_tree_detector.dart` | **New.** The production detector: walks the focus tree and memoises focus node → `RenderEditable`. |
| `lib/src/widgets/textfield_occlusion_policy.dart` | **New.** Pure, Flutter-free policy resolving the three additive sources and the per-screen rule into one effective decision. |
| `lib/src/widgets/textfield_rect_store.dart` | **New.** Per-screen adapter buckets, first-discovery attribution, detach grace, and live serialization. |
| `lib/src/widgets/textfield_occlude_render_box.dart` | **New.** Adapter implementing `OcclusionReportingRenderBox` over an arbitrary discovered `RenderBox`. Not part of the render tree — it *wraps* a field it does not own. Owns the sliding window and the motion margin. |
| `lib/src/widgets/occlusion_rect_codec.dart` | **New.** The wire format, shared by wrapper entries and text-field rects so both go out identically. |
| `lib/src/widgets/occlusion_registry.dart` | Coordinator: method-channel endpoints, frame scheduling, the metrics-change freeze, and the wrapper-entry lifecycle. |
| `lib/src/widgets/occlude_render_box.dart` | Refactored to consume `occlusion_geometry.dart`; its internal checkers moved there. |
| `lib/src/flutter_uxcam.dart` | `occludeAllTextFields(bool)` now also feeds the registry's policy (in addition to the existing native forward); `tagScreenName` feeds the current screen. |

**Native / cross-platform components:**

| File (repo) | Role |
|------|------|
| `android/.../FlutterUxcamPlugin.java` (plugin) | `buildOcclusionRequestArgs()` reads the flag off the delegate **reflectively** and forwards `{ occludeAllTextFields, currentScreen }` to Dart. |
| `screenshot/.../screenshotTaker/CrossPlatformDelegate.java` (android-sdk) | Carries `occludeAllTextFields` + `currentScreenName` (getter/setter) — the shared IPC surface between SDK and plugin. |
| `screenshot/.../capture/CrossPlatformOcclusionBridge.kt` (android-sdk) | Publishes the resolved `CrossPlatformOcclusionSettings` on the delegate before requesting rects for the frame. |
| `screenshot/.../capture/FrameCaptureOrchestrator.kt` (android-sdk) | Resolves the effective per-screen flag via `OcclusionDecisionRepository.shouldOccludeTextFields(...)`. |
| `UXFlutterMethodChannelBridge` (iOS SDK) | Pushes `occludeAllTextFields` on the `requestSceneFrame` method call (pre-existing). |

### 4.2 Discovery — finding the fields

`FocusTreeDetector.collect()` walks down from `FocusManager.instance.rootScope`
and examines **leaf** focus nodes only — never a `FocusScopeNode`, and never a
node with children. A field's own focus node is always a leaf, whereas a scope
or a `Scrollable`'s node has the whole screen (or the whole list) as its render
subtree, so descending from either would cost more than the render walk this
replaces.

Under each leaf it descends at most **12 render objects** looking for a
`RenderEditable`, and memoises the result per focus node — negative results
included, which is where most of the saving comes from: `ListTile` wraps content
in an `InkWell`, which installs a `Focus` node, so a long list is many leaf nodes
with no field beneath them. Caching a negative is safe because a field appearing
later brings its own `Focus` node, which makes the cached node a non-leaf and
stops it being consulted.

Cost scales with the number of focusable widgets rather than total screen
complexity: measured on a real form, **112k node visits against the render walk's
2.1M**, and 5 nodes examined per field found instead of 103. Correctness is the
constraint, not speed — a field the focus tree misses renders normally and
silently stops being masked — so `focus_tree_detector_test` asserts parity with
`RenderEditableDetector` across every field type, including `ExcludeFocus` and
`ExcludeSemantics`.

For each `RenderEditable` found (`findDecoratorAncestor`):

- It climbs up to **24 ancestors** looking for the `InputDecorator`'s decoration
  render object (`SlottedContainerRenderObjectMixin`). That box's bounds already
  cover the **full visible field** — content padding, border, prefix/suffix
  icons — so the mask matches what the user sees. `_RenderDecoration` sits 11
  above the `RenderEditable` of a Material `TextField`; a lower cap silently
  never reaches it.
- `ListTile` and `Chip` use the same slotted mixin, so they are named exclusions
  — a field inside one would otherwise mask the whole row. Unrecognised slotted
  types are treated as decorators: an oversized mask is caught by a test, an
  unmasked field is not.
- If no decorator is found (e.g. a raw `EditableText` or a `CupertinoTextField`),
  it falls back to the bare `RenderEditable` (just the glyph area) and flags it
  so the adapter pads the rect to approximate the tappable field.

### 4.3 Identity & lifecycle

- Each adapter's `stableId` is `Object.hash('textfield', identityHashCode(box))`
  (`TextFieldOccludeRenderBox.stableIdFor`), so the *same* render object maps to
  the *same* store entry across scans — no duplicate masks, no churn while a
  field stays on screen.
- Discovery (`TextFieldRectStore.reconcile`) only **adds**: a field already known
  keeps its original screen bucket, a new one gets an adapter in the active
  bucket. Removal is not decided here.
- Removal is tier-1's job (`updateBounds`), which prunes by detachment every
  frame — authoritative, and never lagging the frame a field leaves the tree. A
  detached field's last bounds move to a **500 ms grace ghost** so a capture that
  raced the detach never shows it unmasked.

### 4.4 Bounds computation (per frame)

`TextFieldOccludeRenderBox.updateBoundsFromTransform()`:

1. Skips if detached / unsized.
2. Resolves visibility, global transform and accumulated ancestor clip in **one**
   `resolveOcclusionGeometry()` pass, and clears bounds if the field is
   effectively invisible (hidden `IndexedStack` branch, off-screen sliver, parent
   not painting it). A `RenderEditable` sits ~63 ancestors deep and this runs per
   field per frame, so the single pass replaces three separate traversals — one
   of which called `getTransformTo` per clipping ancestor, making it
   O(depth × clips) on its own.
3. Transforms the field's local rect to global coordinates.
4. Applies fallback padding **only** for the bare-`RenderEditable` case.
5. Intersects with the resolved clip so a mask never spills outside a scroll
   viewport or clipped container.
6. Keeps a 100 ms sliding window of bounds (matching `OccludeRenderBox`) so a
   single dropped frame can't briefly reveal the field.
7. Extends the served union along the direction of travel, **per edge**. The union
   covers where the field has *been*, so the leading edge needs projecting forward
   over the worst-case staleness (one bounds interval + one frame of capture skew).
   Each edge is projected from its own velocity: deriving the whole rect's motion
   from the top-left corner models pure translation, but a field that *grows* has
   left/top and right/bottom travelling in opposite directions — a dialog scaling
   in left its advancing right and bottom edges unextended and exposed for the
   whole transition. Edges travelling inward are not pulled in; the union already
   covers them. With velocity unknown (fewer than two samples, or two inside the
   same millisecond) it falls back to an all-direction inflate, bounded by adapter
   age so a settled field does not keep it forever.

### 4.5 Keyboard / rotation handling

`didChangeMetrics()` fires on keyboard show/hide, rotation and window resize.
Layout takes several frames to settle, during which per-frame bounds jump around.
The registry sets a `_metricsChanging` flag for **500 ms** and clears the sliding
windows. The two occlusion kinds then diverge, because they want opposite things:

- **Wrapper/config occlusion freezes.** It serves the **last-known bounds** during
  the window so masks stay put instead of flickering while the keyboard animates.
- **Text fields track, and re-arm the inflate.** Discovery and bounds keep running
  (a freeze would leave a field that appears *with* the keyboard unmasked), so the
  mask follows the field as it slides. But clearing the window also wipes the
  velocity history a pre-existing field needs for its motion margin — and that
  field is not *young*, so the blanket unknown-velocity inflate would not otherwise
  apply to it. The clear therefore stamps every field as unknown-velocity for
  150 ms (`_windowClearedMs`), so the field is inflated through the re-acquisition
  and then withdraws to a tight mask on its own. This is what keeps a pre-existing
  field covered on a native-screenshot capture during the keyboard slide, rather
  than exposed for the frame or two before the window refills.

### 4.6 Scheduling — the two-tier frame pipeline

The per-frame work is split so cost scales with what actually changed:

- **Tier 1 — every produced frame, O(#fields):** refresh bounds of *known*
  adapters, move detached fields to a **500 ms grace** (a capture racing a
  detach never shows the field unmasked), expire grace, drop empty buckets.
  This keeps moving fields tracked smoothly during animations.
- **Tier 2 — discovery walk, bounded to every 48 ms** *and forced on the next
  frame* after a screen change (`tagScreenName`), a metrics change
  (keyboard/rotation), a **focus change**, or policy enablement — so a brand-new
  field is still found in its first painted frame, while the walk runs at most
  ~20×/s instead of at the display rate. The discovery buffer is reused across
  scans (no per-frame allocation).
- **Why focus is one of the triggers.** A dialog or route appearing takes focus,
  and that notification lands on the frame it mounts. Without it, a dialog's field
  waited on the 48 ms throttle — three frames unmasked — because a dialog changes
  no screen name and so armed nothing. The signal is free: the focus tree is what
  the detector walks anyway, and the trigger is skipped entirely when the feature
  is off so it never wakes the engine for nothing.
- The frame callback keeps running when the flag is on even with nothing
  registered (bootstrap), and while grace rects are pending after a disable.
- The **native-request path is authoritative, not cached**: it discovers, then
  re-resolves each live adapter's bounds, then serializes those plus the grace
  ghosts. Both throttles above exist to bound *per-frame* cost and neither is
  allowed to decide what a capture sees — a capture landing between refreshes used
  to be answered with geometry up to 33 ms old, and one landing before the next
  scan was answered without the fields that had appeared since the last one. On a
  fling both happen at once: every mask sat a full scroll step behind, and the
  fields scrolling in were represented only by the detach-grace ghosts of the
  items they replaced. It stays cheap because discovery walks the focus tree, not
  the render tree — O(#focusable widgets), one ancestor chain per field, and
  captures arrive a couple of times a second rather than at frame rate.
- **First-discovery attribution:** an adapter stays in the screen bucket where
  it was first discovered and is never re-bucketed. During a route transition
  both screens are mounted; re-bucketing the outgoing screen's fields used to
  leave its old bucket serving stale positions (the main over-occlusion source).

**Internal structure (SRP):** `TextFieldOcclusionPolicy` (pure screen-rule
policy), `TextFieldDetector`/`RenderEditableDetector` (discovery, open for
extension), `TextFieldRectStore` (buckets/attribution/grace, injectable clock),
`OcclusionRectCodec` (wire format), with `OcclusionRegistry` as the coordinator
owning channels, scheduling and the wrapper-entry lifecycle. Covered by unit
tests (policy matrix) and widget tests (first-frame rect, grace expiry, disable
clears, excludeScreens follows the Flutter screen name) under `test/`.

### 4.7 Native-driven activation (verification / dashboard config)

**Source model (enforced in `TextFieldOcclusionPolicy`): every source can only
ADD occlusion, never remove it.** There are three, and they are combined, not
ranked:

| Layer | Fed by | Semantics |
|---|---|---|
| *config* | `updateOcclusionConfiguration` (verification) — **Android today** | Additive. `true` masks on the screens in its own scope. `false` or absent leaves the decision to the others. |
| *frame* | `requestSceneFrame` (iOS) / `requestOcclusionRects` (Android) per capture | Additive, already screen-resolved natively. **On iOS this is the only channel a verification response has.** |
| *manual* | `FlutterUxcam.occludeAllTextFields(bool)` | Blanket — the API takes no screen argument. |

```dart
bool get effective =>
    _configApplies || (manualBase ?? false) || (frameBase ?? false);
```

So `config=true` + `occludeAllTextFields(false)` stays **on**, and
`config=false` + `occludeAllTextFields(true)` is **on** too — neither side can
veto the other. This mirrors both native SDKs: on iOS the dashboard has no
representable "do not occlude text fields" (`UXCamOcclusion` maps
`occludetextfields` and nothing else) and a developer's
`[UXCam occludeAllTextFields:]` survives dashboard resolution; on Android a
manual view-level rule likewise survives
`OcclusionDecisionRepository.shouldOccludeTextFields`.

**Why combined and not ranked — both orderings were tried and both broke.**
Native resolves the per-capture value as the *union* of the dashboard rule and the
developer's own call, and `FlutterUxcam.occludeAllTextFields` forwards into that
same manual layer, so a `true` there cannot be attributed to either source on its
own. Ranking it *above* the API (the original design) meant the public API stopped
having any effect at all once a capture had happened. Dropping it (`e9fda31a`)
broke the opposite case: iOS sends no `updateOcclusionConfiguration`, so
verification lost its only route into Flutter and a dashboard-enabled app recorded
its text fields unmasked. Additive composition is what satisfies both — the value
is trusted to switch masking *on*, never to switch it off.

**The screen scope belongs to the config rule alone.** Narrowing the developer's
blanket request by the server's `excludeScreens` would be the server *removing*
occlusion the app asked for, which it cannot do.

Each `updateOcclusionConfiguration` push is a **complete config statement**: an
absent `occludeAllTextFields` key means "the config does not specify it" and
*clears* the config layer (both native sides send the key only when the
dashboard actually configured it), so the API is in sole control for apps whose
dashboard has no text-field setting. The screen scope is config-owned and
replaced wholesale by each statement. Android delivers the statement through a
**sticky** listener on the capture delegate (`OcclusionConfigurationListener`,
registered reflectively by the plugin), so verification resolving before the
plugin attaches still replays the config — closing Android's first-capture gap.

**Session hygiene.** `OcclusionRegistry` is a process-wide singleton, so
`startWithConfiguration` calls `resetConfigurationLayer()` to drop the previous
session's statement; the developer's API call is preserved, as it is natively.

Flutter-side masking has **three** activation sources:

1. **App code** — `FlutterUxcam.occludeAllTextFields(true)` (also forwarded to
   native so platform-view text fields keep their existing behavior).
2. **A verification config statement** — `updateOcclusionConfiguration`, pushed by
   native when the session settings resolve. Android sends this; iOS does not.
3. **The per-capture flag** on `requestSceneFrame` / `requestOcclusionRects` /
   `requestAllOcclusionRects`. On iOS that value is
   `UXPrivacySettingsProvider.occludeAllTextFields`, derived in
   `refreshTextFieldOcclusionStatus` as
   `containsSettingOfType(OccludeAllTextFields, visibleScreens)` over a
   `dashboard > manual > config` layer stack — the union of the dashboard rule and
   the app's own call, already resolved for the visible screen.

**Consequence for iOS:** since the iOS SDK sends no
`updateOcclusionConfiguration` (no sender exists in `ios-framework/UXCam/Sources`
or `flutter-plugin/ios`), source 3 is the *only* way a verification response
reaches Flutter there. It must therefore be honoured as an enabling signal, even
though it cannot be attributed to the dashboard specifically — the cost of not
honouring it is a dashboard-enabled app recording its Flutter text fields in
clear. Adding the statement in §10 to the iOS SDK would make the signal
attributable and bring per-screen scoping to iOS; the Dart side already consumes
that payload.

**Per-screen rules.** The config statement carries an optional screen scope, so
the config-level "occlude all text fields on / except these screens" applies to
Flutter-rendered fields too:

| Key | Meaning |
|-----|---------|
| `occludeAllTextFields` (bool) | the config rule's master switch |
| `screens` (List&lt;String&gt;) | screens the rule refers to (empty = all screens) |
| `excludeMentionedScreens` (bool) | `true`: the rule applies everywhere *except* `screens`; `false`: *only* on `screens` |
| `excludeScreens` (List&lt;String&gt;) | shorthand for `screens` + `excludeMentionedScreens: true` |
| `currentScreen` (String) | the screen on view, used to evaluate the rule |

`TextFieldOcclusionPolicy._configApplies` evaluates these. With no `screens`
listed the rule is unscoped and applies everywhere. The scope narrows **only the
config rule** — never the blanket manual API. `currentScreen` normally comes from
Flutter's own tagging (`FlutterUxcamNavigatorObserver` /
`FlutterUxcam.tagScreenName`); a per-capture payload may also supply it.

### 4.8 End-to-end activation path (cross-platform)

The two activation sources meet in `TextFieldOcclusionPolicy`, which resolves them
into the single effective decision driving the scan in §3:

```
  DASHBOARD / VERIFICATION CONFIG                     APP CODE
  (server, per session)                    FlutterUxcam.occludeAllTextFields(true)
          │                                                │
          ▼                                                │ (also forwards to
  ┌──────────────────────────────┐                         │  native, for
  │ NATIVE SDK resolves the      │                         │  platform-view
  │ dashboard text-field rule    │                         │  text fields)
  └──────────────┬───────────────┘                         │
                 │                                         │
   Android: sticky OcclusionConfigurationListener          │
            on CrossPlatformDelegate                       │
                 │  (plugin: reflection + dynamic Proxy)   │
                 ▼                                         │
     invokeMethod("updateOcclusionConfiguration",           │
       {occludeAllTextFields?, screens, excludeMentionedScreens})
                 │                                         │
   iOS: NOT SENT — see §10 follow-up                        │
                 │                                         │
                 │   both platforms, every capture:         │
                 │   requestSceneFrame (iOS) /                 │
                 │   requestOcclusionRects (Android)        │
                 │   {occludeAllTextFields, currentScreen}  │
                 │            │                            │
                 ▼            ▼                            ▼
        policy.configBase   policy.frameBase        policy.manualBase
        + screen scope      (screen-resolved
                 │           natively)                     │
                 └──────────────┬──────────────────────────┘
                                ▼
     effective = _configApplies || manualBase || frameBase   (any source may
                                │                             switch it ON;
                                ▼                             none may veto)
                 focus-tree discovery (§3) masks every field
```

The platform difference is only *which* server channel is available: Android has
both the statement and the per-capture flag; iOS has only the per-capture flag, so
that is how verification reaches it. The Dart side is identical either way.

### 4.9 Capture-coherent serving (per capture, not per platform)

Everything in §4.4 and §4.6 — the sampling cadence, the 100 ms sliding window,
the motion margin — exists to compensate for one thing: the gap between *when
bounds were last sampled* and *when the pixels were taken*. Where that gap is
zero, none of it is needed.

That gap is zero for exactly one kind of capture: one whose pixels **Flutter
itself rasterised**. `requestSceneFrame` asks the registry for rects and then
rasterises the root layer, with **no `await` between the two**. Dart is
single-threaded and a frame cannot be produced inside that gap, so both read the
same committed frame: the rects describe exactly the pixels being captured. For
that capture — and only that capture — `serializeRects(coherent: true)` serves:

- **The exact rect, no sliding window, no motion margin** — the exact rect *is*
  the answer, and widening it would mask more of the frame than the field covers.
- **No detach grace.** A grace rect covers a capture that raced a detach; the scan
  ran inside this capture, so there is no race, and serving a departed field's
  last position would mask a region the frame no longer shows.

> **Load-bearing order.** Do not introduce an `await` between resolving the rects
> and `toImage`, and do not hoist the rects to a cache filled earlier. Either
> reinstates the staleness those mechanisms existed to hide, with nothing left to
> hide it. And whether a scene-frame capture is coherent is decided **before** the
> rects are resolved, from whether Flutter will actually supply the pixels
> (`_handleSceneFrameRequest`'s `canProvidePixels`): a rect stamped coherent but
> paired with a native screenshot is the un-widened, lagging mask this path exists
> to prevent.

**Coherence is a property of the capture, not the platform.** Earlier this was a
static per-platform flag (`_captureCoherent`, true on iOS) that switched the whole
pipeline off — on the assumption that every iOS capture is a Flutter-rendered
scene frame. It is not: the shipping iOS SDK screenshots **natively** and requests
rects via `requestAllOcclusionRects`, a separate async hop later. With the
compensation statically disabled, a fast scroll paired the older native screenshot
with newer exact rects, so every mask trailed the fields and exposed them on the
leading edge — the QA-reproduced glitch.

So the pipeline now **always runs** (frame-driven sampling, window, margin, grace),
on every platform, and each capture chooses whether to widen:

| Capture | Coherent? | Served |
| --- | --- | --- |
| `requestSceneFrame` **with** Flutter pixels | yes | exact rects |
| `requestSceneFrame` without pixels (webview / presented / keyboard up) | no | widened |
| `requestAllOcclusionRects` / `requestOcclusionRects` (native screenshot) | no | widened |

Static content is unaffected either way; a field moving at capture time is covered
by the window + motion margin on every non-coherent path, including the keyboard-up
and webview cases that previously trailed their masks.

### 4.10 Scene frames (Android transport)

`requestSceneFrame` is also wired on Android, through
`CrossPlatformDelegate.setSceneFrameListener`. Dart renders the frame and returns
pixels *and* geometry in one response; the plugin's `parseSceneFrameResponse`
converts it to the SDK's `SceneFrameResponse` and nothing more — every judgement
about whether the payload is usable lives in the SDK, where it is unit-testable
(`FlutterUxcamPluginSceneFrameTest`).

Two rules the parser enforces:

- **Geometry and pixels are judged independently**, matching iOS. Unusable rects
  do not discard a usable raster — they mark the metadata so the SDK can cover
  the frame while still recording a real one. A missing raster with good rects is
  a normal outcome, not an error.
- **The rect key shape identifies the units, not the `coordinateSpace` string.**
  Dart stamps that field with the iOS answer on every platform while its Android
  encoder emits device pixels, so the two disagree; `left/top/right/bottom` means
  device pixels, `x0/y0/x1/y1` means logical points.

Android's capture is not *yet* driven from Flutter end-to-end, so its captures are
served non-coherent (widened) — the same path §4.9 puts the native-screenshot iOS
captures on. Once a scene-frame capture there supplies Flutter pixels, it becomes
coherent automatically, by the same per-capture rule; no platform switch is
involved.

---

## 5. Design decisions & caveats

- **No `FlutterUxConfig` flag.** The earlier config option was removed. The API
  still forwards to native so platform-view text fields keep their existing
  behavior.
- **Sources are combined, not ranked; none can veto another.** Matching both
  native SDKs (§4.7), where no source can reduce another's occlusion. Ranking was
  tried in both directions and each ordering broke a real case: with the
  per-capture flag above the API, `occludeAllTextFields` became a no-op after the
  first capture; with it removed entirely, iOS verification lost its only channel
  into Flutter and dashboard-enabled apps recorded their fields in clear. An OR
  has no ordering to get wrong, and errs toward masking.
- **The consequence to accept:** because the per-capture value cannot be
  attributed, `occludeAllTextFields(false)` cannot switch off masking that the
  dashboard enabled. That is the native contract, not a Flutter quirk — on iOS the
  dashboard layer outranks the manual one in `occlusionForScreens`, and there is no
  representable dashboard "off" to begin with.
- **Modularity over reuse-by-exposure.** Shared math lives in
  `occlusion_geometry.dart`; the text-field box never reaches into
  `OccludeRenderBox` internals. The whole feature can be deleted cleanly.
- **Decoration box preferred over glyph box.** Masking the `InputDecorator`
  gives a rect that matches the visible field; padding is a fallback, not the
  default, to avoid oversized masks.
- **Adapters don't own their target.** `TextFieldOccludeRenderBox` wraps a
  render object it didn't create, so it must tolerate that object detaching at
  any time — hence the attached/size guards and the detach-on-scan diffing.
- **No release-time logging.** Debug prints that emitted occlusion coordinates
  were removed; rect data is never written to logs.

---

## 6. Results

- **One-line activation** masks every Material/Cupertino text field with no
  per-widget wrapping.
- **Zero-code activation too** — verification activates the scan with no app
  change, on both platforms: Android through the config statement, iOS through the
  per-capture flag (§4.7–4.8).
- **No source is overruled downward** — every source can only add masking, so
  `occludeAllTextFields(true)` always takes effect and a verification `true` always
  takes effect. Neither can be silently cancelled by the other.
- **Platform-agnostic Dart side** — both platforms drive the same policy and the
  same focus-tree discovery; only which server channel is available differs.
- **Safe version skew** — new plugin ⇄ old SDK and old plugin ⇄ new SDK both
  degrade to "inactive, no error" (§11), so the feature can ship ahead of the
  native SDK release.
- **Reuses the proven pipeline** — the same bounds/clip/visibility/sliding-window
  machinery as manual occlusion, so behavior (including scroll clipping and
  IndexedStack/viewport visibility) is consistent between manual and automatic
  masks.
- **Correct field coverage** by masking the decoration box; padding only where
  no decoration exists.
- **Stable during keyboard & rotation** thanks to the metrics-change freeze.
- **Bounded cost** — throttled per-frame work (one scan per interval), with the
  capture path paying for a fresh scan and bounds resolve so correctness never
  depends on where a capture lands relative to those throttles.
- **Fully modular & analyzer-clean**; removing the feature touches nothing in
  widget occlusion.

---

## 7. Limitations

1. **Discovery latency no longer reaches the recording.** Every capture discovers
   and re-resolves bounds before answering (§4.6), so a field is masked in the
   first captured frame it exists in, whatever the frame-driven throttles were
   doing. The throttles still delay when a field enters the *bounds history*,
   which is what feeds the velocity projection — a field that appears and
   immediately accelerates has one capture's worth of margin derived from the
   unknown-velocity inflate rather than measured motion.
2. **`RenderEditable` only.** Non-editable sensitive text — `SelectableText`,
   plain `Text`, and anything rendered via `RenderParagraph` — is **not** caught.
   Only editable fields are covered.
3. **Fallback padding is a heuristic.** For undecorated `EditableText`, the
   fixed padding (12 px H / 16 px V) approximates the field; unusual custom
   layouts may be slightly over- or under-covered.
4. **Discovery walk cost.** Discovery is O(#focusable widgets) per scan — it
   walks the focus tree, not the render tree (112k node visits against 2.1M on a
   real form). The 48 ms throttle bounds what remains.
5. **Decorator search depth is capped at 24.** A deeply/custom-nested decoration
   beyond 24 ancestors falls back to the glyph box + padding rather than the true
   decoration bounds.
6. **Platform-view text fields** (native views embedded via `PlatformView`) are
   not Flutter render objects and are out of scope for the Dart-side scan; they
   rely on the native `occludeAllTextFields` path.
7. **Android activation requires the new Android SDK.** The Android path is now
   wired end-to-end (SDK resolves the per-screen flag → publishes it on the
   shared capture delegate → the plugin reads it reflectively → Dart), but the
   SDK half ships in a **later Android SDK release**. Until an app upgrades to
   that SDK the plugin finds no flag on the delegate and the feature stays
   inactive — see §11 for the compatibility guarantees.
8. **iOS has no zero-code activation yet.** The iOS SDK sends no
   `updateOcclusionConfiguration`, so Flutter-side masking on iOS is API-driven
   only. Native `UITextField`s are still masked by the native SDK from its own
   derived flag; only Flutter-drawn fields wait on the statement in §10. The Dart
   side already consumes the full payload, screen keys included.

---

## 8. Further scope / improvements

- **Fully event-driven discovery.** Focus changes are honoured today, and every
  capture discovers regardless, so the throttles no longer gate what gets masked.
  A registration hook at `RenderEditable` attach time would let the per-frame
  polling go away entirely and give every field a full bounds history from birth.
- **Extend to non-editable sensitive text.** Optionally detect `RenderParagraph`
  / `SelectableText` behind an opt-in (`occludeAllText`) for apps that display
  (not just input) sensitive data.
- **Incremental scanning.** Cache the previous tree snapshot and only diff
  changed subtrees, avoiding a full walk every interval.
- **Per-field opt-out.** An allow-list / "do not occlude" marker for fields that
  are safe (e.g. a search box), so "occlude all" can have deliberate exceptions.
- **Configurable padding / detection depth.** Expose the fallback padding and
  decorator search depth for apps with unusual field layouts.
- **Automated tests.** Widget tests asserting that a `TextField` produces an
  occlusion rect, that a scrolled-off field stops producing one, and that the
  keyboard-open transition keeps a stable rect.
- **iOS per-screen keys.** Add `screens` / `excludeMentionedScreens` /
  `currentScreen` to the iOS `requestSceneFrame` push so per-screen rules apply on
  iOS too (Android already resolves them to the effective boolean natively). The
  Dart side already consumes these keys.

---

## 9. Public API

```dart
/// Automatically occlude every TextField in the app.
/// Pass false to turn it back off.
FlutterUxcam.occludeAllTextFields(true);
```

No configuration flag; call any time after `startWithConfiguration`. Passing
`true` always takes effect. Passing `false` switches off only what this call
turned on — it cannot cancel occlusion the dashboard/verification settings enabled
(§4.7). Where the dashboard carries no text-field setting, this call is the sole
control. Zero-code activation from the dashboard needs no app change on either
platform: Android through the §10 statement, iOS through the per-capture flag.

## 10. Native → Flutter contract (for SDK maintainers)

Dashboard/verification-driven activation requires a **config statement**, sent
once when the session settings resolve — not a per-capture flag:

```jsonc
// invokeMethod("updateOcclusionConfiguration", …)
{
  "occludeAllTextFields": true,        // OMIT when the dashboard did not
                                       //   configure it — an absent key clears
                                       //   the config layer and hands control
                                       //   back to the Dart API
  "screens": ["Login", "Payment"],     // optional — the rule's own screen scope
  "excludeMentionedScreens": false,    // optional — include/exclude semantics
  "excludeScreens": ["Search"],        // optional — shorthand for the above two
  "currentScreen": "Login"             // optional — needed to evaluate screens
}
```

Each push is a **complete statement**: whatever it omits reverts to its default,
so it fully describes the dashboard's current rule. Send it as early as
verification resolves, and make delivery **sticky** so a plugin attaching later
still receives the last statement.

- **Android — done.** The SDK resolves the dashboard rule and hands it to a sticky
  `CrossPlatformDelegate.OcclusionConfigurationListener`; the plugin registers
  reflectively (`attachOcclusionConfigListenerIfSupported`) and forwards it.
- **iOS — to do.** Send this statement from `UXFlutterMethodChannelBridge` when
  `applyVerifiedVideoPrivacySettings:` runs, carrying the dashboard's
  `textFieldPrivacy` rule (and the legacy `verifyDataSettings.occludeAllTextFields`),
  with the key omitted when the dashboard configured nothing. Until then iOS
  verification works only through the per-capture flag below, which means it cannot
  express per-screen scoping to Flutter and cannot be told apart from the app's own
  API call.

The per-capture payload on `requestSceneFrame` / `requestOcclusionRects` /
`requestAllOcclusionRects` carries `currentScreen` and an `occludeAllTextFields`
value that **is honoured as an enabling signal** — it is how verification reaches
Flutter on iOS. Keep sending the effective, screen-resolved value on every capture;
it is read every time, so it may fall as well as rise. It cannot switch masking
*off* on its own, because Dart cannot tell it apart from an echo of the app's own
API call (§4.7).

## 11. Version compatibility (plugin ⇄ Android SDK)

The plugin and the UXCam Android SDK are **separately versioned artifacts**; an
app can pair any plugin version with any SDK version. The wiring is designed so
mismatches degrade silently — the feature is simply inactive, never an error:

| Plugin | Android SDK | Behavior |
|--------|-------------|----------|
| new | new | Zero-code activation live — SDK pushes the config statement, plugin forwards it. |
| **new** | **old** | The plugin resolves the listener and the delegate getters **reflectively**; on an older SDK they're absent, so no statement arrives → the Dart API is the only activation path. No crash, no `NoSuchMethodError`. |
| old | new | The old plugin never registers the listener → ignored. Harmless. |
| old | old | Unchanged prior behavior. |

In every row the Dart API keeps working: it needs nothing from the native side.

Why it holds:
- **No interface break.** The SDK carries the flag as fields on the existing
  `CrossPlatformDelegate` (a getter/setter pair), not via a changed
  `OcclusionRectRequestListener` signature — so an old plugin still compiles and
  links against the new SDK.
- **Reflection, not a hard reference.** The plugin is compiled against the
  released SDK (`com.uxcam:uxcam:3.10.6`), which predates these methods; it must
  not reference them directly or it would fail to build. `buildOcclusionRequestArgs()`
  resolves them via `getMethod(...)` once and caches the result.
- **Defensive Dart parsing.** `_applyNativeOcclusionSettings` no-ops on `null`
  args and type-checks every key, so a plugin sending nothing (or a partial map)
  is safe.
