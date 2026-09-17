/// Pure policy for "occlude all text fields": holds the session configuration
/// (from the Dart API or pushed by the native SDK after verification) and
/// resolves it against the current screen into a single effective decision.
///
/// Deliberately free of Flutter imports so the screen-rule matrix can be unit
/// tested without a render tree.
///
/// **Source model — every source can only ADD occlusion.** This mirrors both
/// native SDKs: on iOS the dashboard has no representable "do not occlude text
/// fields" (`UXCamOcclusion` maps `occludetextfields` and nothing else) and a
/// developer's `[UXCam occludeAllTextFields:]` always survives dashboard
/// resolution; on Android a manual view-level rule likewise survives
/// (`OcclusionDecisionRepository.shouldOccludeTextFields`). So masking is on when
/// *any* source asks for it, and where no source asks, it is off.
///
/// The three sources are deliberately combined rather than ranked. An earlier
/// version ranked them, letting the per-capture value shadow the Dart API — which
/// meant `FlutterUxcam.occludeAllTextFields` had no effect at all once a capture
/// had happened. Removing that source instead broke the opposite case: iOS sends
/// no `updateOcclusionConfiguration`, so the per-capture value is the *only*
/// channel a verification response has there, and dropping it left verification
/// unable to switch masking on. Combining them additively is what satisfies both.
class TextFieldOcclusionPolicy {
  /// Set by the Dart API `FlutterUxcam.occludeAllTextFields(bool)`. Blanket by
  /// nature: the API takes no screen argument, exactly as native applies it
  /// (`applyManualOcclusionSetting:toScreens:@[]`).
  bool? manualBase;

  /// The verification/dashboard configuration, delivered via
  /// `updateOcclusionConfiguration` when the session settings resolve. Additive:
  /// `true` switches masking on for the screens in its own scope; `false` or
  /// absent simply leaves the decision to the other sources.
  bool? configBase;

  /// The native SDK's per-capture value — iOS `requestSceneFrame`, Android
  /// `requestOcclusionRects`. Screen-resolved natively before it is sent.
  ///
  /// Native computes it as the union of the dashboard rule and the developer's
  /// own call, and the Dart API forwards into that same manual layer, so a `true`
  /// here cannot be attributed to either on its own. That is exactly why it is
  /// additive and not a priority: as an *enabling* signal it is sound — on iOS it
  /// is how a verification response reaches Flutter at all — while as a ranked
  /// source it silently disabled the public API.
  bool? frameBase;

  /// Screens the configuration's rule refers to. Empty = the rule is unscoped
  /// and applies on every screen.
  ///
  /// Config-owned: it scopes the configuration's rule only, never [manualBase].
  /// Narrowing a developer's blanket request by the server's exclusion list
  /// would be the server *removing* occlusion, which it cannot do.
  List<String> screens = const [];

  /// When true, [screens] are the screens to *exclude* (the configuration's rule
  /// applies everywhere else). When false, they are the *only* screens it
  /// applies to.
  bool excludeMentionedScreens = false;

  /// The screen currently on view, sourced from Flutter's own tagging
  /// (`FlutterUxcamNavigatorObserver` / `FlutterUxcam.tagScreenName`), or from
  /// the native per-capture payload.
  String? currentScreen;

  /// Whether the configuration's own rule applies on [currentScreen].
  ///
  /// An unknown current screen fails safe: exclusion rules over-occlude rather
  /// than leak.
  bool get _configApplies {
    if (configBase != true) return false;
    if (screens.isEmpty) return true;
    final onListedScreen =
        currentScreen != null && screens.contains(currentScreen);
    return excludeMentionedScreens
        ? !onListedScreen // applies everywhere EXCEPT the listed screens
        : onListedScreen; // applies ONLY on the listed screens
  }

  /// The effective decision for the current screen: on when the configuration's
  /// rule applies here, or the Dart API asked for it, or the native SDK's
  /// per-capture value says so.
  bool get effective =>
      _configApplies || (manualBase ?? false) || (frameBase ?? false);

  /// Applies occlusion settings pushed down by the native SDK and returns
  /// whether any recognised key changed the held state.
  ///
  /// Recognised keys (all optional):
  ///  * `occludeAllTextFields` (bool)   — the configuration's master switch.
  ///  * `excludeScreens` (List<String>) — verification's optional exclusion
  ///    list: the rule applies on every screen EXCEPT these. Shorthand that sets
  ///    `screens` + `excludeMentionedScreens = true`.
  ///  * `screens` (List<String>)        — screens the rule refers to.
  ///  * `excludeMentionedScreens` (bool) — true: applies everywhere except
  ///    `screens`; false: applies only on `screens`.
  ///  * `currentScreen` (String)        — evaluated against the screen rule.
  ///
  /// [isConfigSource] selects the semantics:
  ///  * `true` — the verification-time `updateOcclusionConfiguration` push, a
  ///    **complete config statement**: [configBase] and the screen scope are
  ///    replaced by what the statement carries. An absent
  ///    `occludeAllTextFields` key means "the config does not specify it" and
  ///    *clears* [configBase], handing control back to the manual API for apps
  ///    whose dashboard has no text-field setting.
  ///  * `false` — a per-capture payload: `occludeAllTextFields` lands in
  ///    [frameBase] and `currentScreen` is read. The screen scope is config-owned
  ///    and left alone, since the per-capture flag is already screen-resolved
  ///    natively.
  bool applyNativeSettings(dynamic arguments, {required bool isConfigSource}) {
    if (arguments is! Map) return false;
    return isConfigSource
        ? _applyConfigStatement(arguments)
        : _applyPerCaptureValues(arguments);
  }

  /// Drops the layers the native side owns — the verification/dashboard statement
  /// and the last per-capture value — so neither outlives the session it came
  /// from. The manual layer is deliberately preserved: the developer's call
  /// survives a session restart, as it does natively.
  ///
  /// [frameBase] is safe to drop because the next capture re-sends it.
  bool clearConfiguration() {
    if (configBase == null &&
        frameBase == null &&
        screens.isEmpty &&
        !excludeMentionedScreens) {
      return false;
    }
    configBase = null;
    frameBase = null;
    screens = const [];
    excludeMentionedScreens = false;
    return true;
  }

  bool _applyConfigStatement(Map arguments) {
    final flag = arguments['occludeAllTextFields'];
    final bool? newConfigBase = flag is bool ? flag : null;

    List<String> newScreens = const [];
    var newExclude = false;
    // `excludeScreens` (verification shorthand) = the rule applies everywhere
    // except the listed screens.
    if (arguments['excludeScreens'] is List) {
      newScreens = (arguments['excludeScreens'] as List)
          .whereType<String>()
          .toList(growable: false);
      newExclude = true;
    } else if (arguments['screens'] is List) {
      newScreens = (arguments['screens'] as List)
          .whereType<String>()
          .toList(growable: false);
      newExclude = arguments['excludeMentionedScreens'] is bool
          ? arguments['excludeMentionedScreens'] as bool
          : false;
    }

    var changed = false;
    if (configBase != newConfigBase) {
      configBase = newConfigBase;
      changed = true;
    }
    if (!_sameScreens(screens, newScreens) ||
        excludeMentionedScreens != newExclude) {
      screens = newScreens;
      excludeMentionedScreens = newExclude;
      changed = true;
    }
    if (_applyCurrentScreen(arguments)) changed = true;
    return changed;
  }

  bool _applyPerCaptureValues(Map arguments) {
    var changed = false;
    final flag = arguments['occludeAllTextFields'];
    if (flag is bool && frameBase != flag) {
      frameBase = flag;
      changed = true;
    }
    if (_applyCurrentScreen(arguments)) changed = true;
    return changed;
  }

  bool _applyCurrentScreen(Map arguments) {
    final value = arguments['currentScreen'];
    if (value is String && currentScreen != value) {
      currentScreen = value;
      return true;
    }
    return false;
  }

  static bool _sameScreens(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
