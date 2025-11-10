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

  final Map<Route<dynamic>, String> _resolvedNames = <Route<dynamic>, String>{};

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
    final name = _resolveNameByRoute(route);
    if (name != null) {
      _screenNames.add(name);
      setAndTaggingScreenName();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final oldName = _resolveNameByRoute(oldRoute);
      if (oldName != null) {
        _screenNames.remove(oldName);
      }
      _resolvedNames.remove(oldRoute);
    }
    if (newRoute != null) {
      final newName = _resolveNameByRoute(newRoute);
      if (newName != null) {
        _screenNames.add(newName);
      }
    }
    setAndTaggingScreenName();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _topRoute = previousRoute;
    final name = _resolveNameByRoute(route);
    if (name != null) {
      _screenNames.remove(name);
    }
    _resolvedNames.remove(route);
    setAndTaggingScreenName();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    final name = _resolveNameByRoute(route);
    if (name != null) {
      _screenNames.remove(name);
    }
    _resolvedNames.remove(route);
    setAndTaggingScreenName();
    super.didRemove(route, previousRoute);
  }

  String? _resolveNameByRoute(Route<dynamic> route) {
    final cached = _resolvedNames[route];
    if (cached != null) return cached;

    //give user assigned names the highest priority
    final explicitName = route.settings.name;
    if (explicitName != null && explicitName.isNotEmpty) {
      _resolvedNames[route] = explicitName;
      return explicitName;
    }

    if (route is PageRoute<dynamic>) {
      final context = route.subtreeContext;
      if (context != null) {
        final name = context.widget.runtimeType.toString();
        _resolvedNames[route] = name;
        return name;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = route.subtreeContext;
        if (context != null) {
          _resolvedNames[route] = context.widget.runtimeType.toString();
          setAndTaggingScreenName();
        }
      });
      return null;
    }

    return null;
  }

  /// This function will just perform operation for setting [taggingScreen] and
  /// depeding on the value of  [taggingScreen] will either discard or perform
  /// [FlutterUxcam.tagScreenName] operation.
  void setAndTaggingScreenName() {
    print("cachedNames :${_resolvedNames}");
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
