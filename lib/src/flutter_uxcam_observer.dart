import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
  void setAndTaggingScreenName() {
    String taggingScreen = '';
    List<String> currentStackNames = List.from(_screenNames);
    if (currentStackNames.isNotEmpty) {
      taggingScreen = currentStackNames.last;
    }
    if (taggingScreen.isNotEmpty && !taggingScreen.startsWith(":")) {
      FlutterUxcam.tagScreenName(taggingScreen);
    }
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
