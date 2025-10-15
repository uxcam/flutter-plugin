import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// Here using NavigatorObserver instead of [RouteObserver] because
/// [RouteObserver] only works for Navigator 1.0 and will log nothing
/// or perform no calls in case of Navigator 2.0.
class FlutterUxcamNavigatorObserver extends NavigatorObserver {
  Route? _topRoute;
  Route? get topRoute => _topRoute;

  FlutterUxcamNavigatorObserver._internal();

  factory FlutterUxcamNavigatorObserver() {
    final instance = FlutterUxcamNavigatorObserver._internal();
    UxCam.navigationObserver = instance;
    return instance;
  }

  /// Using this approach as we need to keep track of screens
  /// before this one and keep track of screens previous to the
  /// current one.
  final List<String> _screenNames = [];
  List<String> get screenNames => _screenNames;

  /// Cache the last tagged screen name to avoid redundant method channel calls
  String? _lastTaggedScreenName;

  /// Timer for debouncing screen name tagging to avoid excessive calls
  Timer? _debounceTimer;

  Animation<double>? _transitionAnimation;
  Animation<double>? get transitionAnimation => _transitionAnimation;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    _topRoute = route;
    if (route is PageRoute) {
      _transitionAnimation = route.animation;
    }

    /// This line of code is required as there are scenarios where we have
    /// routing like in popup menu but it is not handled by routing in
    /// [onGenerateRoute].
    if (route.settings.name != null) {
      _screenNames.add(route.settings.name!);
    } else if (route is DialogRoute || route is ModalBottomSheetRoute) {
      _screenNames.add(":popup");
    }
    setAndTaggingScreenName();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _screenNames.remove(newRoute?.settings.name);
    setAndTaggingScreenName();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _topRoute = previousRoute;
    if (route is PageRoute) {
      _transitionAnimation = route.animation;
      _screenNames.remove(route.settings.name);
    } else {
      _screenNames.removeWhere((e) => e == ":popup");
    }
    setAndTaggingScreenName();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _screenNames.remove(route.settings.name);
    setAndTaggingScreenName();
    super.didRemove(route, previousRoute);
  }

  /// This function will just perform operation for setting [taggingScreen] and
  /// depeding on the value of  [taggingScreen] will either discard or perform
  /// [FlutterUxcam.tagScreenName] operation.
  /// 
  /// Optimized for Impeller performance by:
  /// 1. Avoiding unnecessary list copies
  /// 2. Caching last tagged screen name to prevent redundant calls
  /// 3. Deferring method channel calls to post-frame callback
  /// 4. Debouncing rapid navigation events
  void setAndTaggingScreenName() {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();
    
    // Get the current screen name without creating a list copy
    final String taggingScreen = _screenNames.isNotEmpty ? _screenNames.last : '';
    
    // Skip if empty, starts with ":", or is the same as last tagged screen
    if (taggingScreen.isEmpty || 
        taggingScreen.startsWith(":") || 
        taggingScreen == _lastTaggedScreenName) {
      return;
    }
    
    // Debounce rapid navigation events (50ms window)
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      // Double-check the screen name hasn't changed during debounce
      final currentScreen = _screenNames.isNotEmpty ? _screenNames.last : '';
      if (currentScreen == taggingScreen && currentScreen != _lastTaggedScreenName) {
        // Defer the method channel call until after the current frame
        // This prevents blocking the navigation animation
        SchedulerBinding.instance.addPostFrameCallback((_) {
          FlutterUxcam.tagScreenName(taggingScreen);
        });
        _lastTaggedScreenName = taggingScreen;
      }
    });
  }

  /// Cleanup method to cancel any pending timers
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  bool isPopupOnTop() {
    if (_topRoute != null) {
      return (_topRoute is DialogRoute || _topRoute is ModalBottomSheetRoute) &&
          _topRoute!.isActive &&
          _topRoute!.isCurrent;
    }
    return false;
  }
}
