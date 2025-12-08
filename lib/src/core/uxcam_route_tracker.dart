import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

class _RouteInfo {
  final String? name;
  final Route? route;
  final DateTime timestamp;

  _RouteInfo({
    this.name,
    this.route,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Route tracker supporting Navigator 1.0 and 2.0.
class UXCamRouteTracker with WidgetsBindingObserver {
  // Use eager singleton to prevent resurrection issues
  static final UXCamRouteTracker _instance = UXCamRouteTracker._internal();
  factory UXCamRouteTracker() => _instance;
  UXCamRouteTracker._internal();

  final Map<NavigatorState, List<_RouteInfo>> _navigatorStacks = {};
  late UXCamNavigatorObserver _rootObserver;
  bool _isInitialized = false;
  void Function()? onRouteChanged;

  void initialize({void Function()? onRouteChanged}) {
    if (_isInitialized) return;
    _isInitialized = true;

    this.onRouteChanged = onRouteChanged;
    _rootObserver = UXCamNavigatorObserver(this, 'root');
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);
    _navigatorStacks.clear();
    _isInitialized = false;
    // Don't null out _instance - eager singleton prevents resurrection
  }

  NavigatorObserver get navigatorObserver => _rootObserver;

  NavigatorObserver createObserverForNavigator(String navigatorId) {
    return UXCamNavigatorObserver(this, navigatorId);
  }

  String getRouteForElement(Element element) {
    try {
      final modalRoute = ModalRoute.of(element);

      if (modalRoute != null) {
        final name = modalRoute.settings.name;
        if (name != null && name.isNotEmpty && name != '/') {
          return name;
        }

        final safeName = _getRouteNameSafe(modalRoute);
        if (safeName != null && safeName.isNotEmpty) {
          return safeName;
        }
      }
    } catch (_) {}

    return _getObserverTrackedRoute() ?? '/';
  }

  /// Get the current route from the observer-tracked stacks.
  /// Routes starting with ':' are considered internal/generated routes
  /// (e.g., ':modal', ':overlay') and are excluded from tracking to prevent
  /// noise in screen analytics.
  String? _getObserverTrackedRoute() {
    for (final stack in _navigatorStacks.values.toList().reversed) {
      if (stack.isNotEmpty) {
        final route = stack.last;
        // Skip routes starting with ':' as they are internal/generated
        if (route.name != null && !route.name!.startsWith(':')) {
          return route.name;
        }
      }
    }
    return null;
  }

  String? _getRouteNameSafe(Route? route) {
    if (route == null) return null;

    final args = route.settings.arguments;
    if (args is Map && args.containsKey('screenName')) {
      return args['screenName'] as String?;
    }

    if (route is PageRoute && route.settings is Page) {
      final page = route.settings as Page;
      if (page.name != null && page.name!.isNotEmpty) {
        return page.name;
      }
      if (page.key is ValueKey) {
        final keyValue = (page.key as ValueKey).value;
        if (keyValue != null) {
          return keyValue.toString();
        }
      }
    }

    final typeName = route.runtimeType.toString();
    return _cleanRouteTypeName(typeName);
  }

  String _cleanRouteTypeName(String typeName) {
    return typeName
        .replaceAll('MaterialPageRoute', '')
        .replaceAll('CupertinoPageRoute', '')
        .replaceAll('PageRoute', '')
        .replaceAll('<dynamic>', '')
        .replaceAll('<void>', '')
        .replaceAll('Route', '')
        .replaceAll('<>', '')
        .trim();
  }

  void onRoutePushed(
      NavigatorState navigator, Route route, Route? previousRoute) {
    _navigatorStacks.putIfAbsent(navigator, () => []);
    _navigatorStacks[navigator]!.add(_RouteInfo(
      name: route.settings.name ?? _getRouteNameSafe(route),
      route: route,
    ));
    _notifyRouteChanged();
  }

  void onRoutePopped(
      NavigatorState navigator, Route route, Route? previousRoute) {
    final stack = _navigatorStacks[navigator];
    if (stack != null && stack.isNotEmpty) {
      stack.removeLast();
    }
    _notifyRouteChanged();
  }

  void onRouteReplaced(
      NavigatorState navigator, Route? newRoute, Route? oldRoute) {
    final stack = _navigatorStacks[navigator];
    if (stack != null && stack.isNotEmpty) {
      stack.removeLast();
    }
    if (newRoute != null) {
      _navigatorStacks.putIfAbsent(navigator, () => []);
      _navigatorStacks[navigator]!.add(_RouteInfo(
        name: newRoute.settings.name ?? _getRouteNameSafe(newRoute),
        route: newRoute,
      ));
    }
    _notifyRouteChanged();
  }

  void onRouteRemoved(
      NavigatorState navigator, Route route, Route? previousRoute) {
    final stack = _navigatorStacks[navigator];
    if (stack != null) {
      stack.removeWhere((info) => info.route == route);
    }
    _notifyRouteChanged();
  }

  void _notifyRouteChanged() {
    onRouteChanged?.call();
    final currentRoute = _getObserverTrackedRoute();
    // Only tag screen name for user-facing routes (not internal routes starting with ':')
    if (currentRoute != null &&
        currentRoute.isNotEmpty &&
        !currentRoute.startsWith(':')) {
      FlutterUxcam.tagScreenName(currentRoute);
    }
  }

  String get currentRouteName => _getObserverTrackedRoute() ?? '/';

  bool isPopupOnTop() {
    for (final stack in _navigatorStacks.values) {
      if (stack.isNotEmpty) {
        final topRoute = stack.last.route;
        if (topRoute != null) {
          if ((topRoute is DialogRoute || topRoute is ModalBottomSheetRoute) &&
              topRoute.isActive &&
              topRoute.isCurrent) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool get isInitialized => _isInitialized;

  @override
  Future<bool> didPopRoute() async {
    _notifyRouteChanged();
    return false;
  }

  @override
  Future<bool> didPushRoute(String route) async {
    _notifyRouteChanged();
    return false;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    _notifyRouteChanged();
    return false;
  }
}

class UXCamNavigatorObserver extends NavigatorObserver {
  final UXCamRouteTracker _tracker;
  final String _navigatorId; // ignore: unused_field

  UXCamNavigatorObserver(this._tracker, this._navigatorId);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (navigator != null) {
      _tracker.onRoutePushed(navigator!, route, previousRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (navigator != null) {
      _tracker.onRoutePopped(navigator!, route, previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (navigator != null) {
      _tracker.onRouteReplaced(navigator!, newRoute, oldRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (navigator != null) {
      _tracker.onRouteRemoved(navigator!, route, previousRoute);
    }
  }
}
