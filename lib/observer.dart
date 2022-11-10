import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// Signature of a function that extracts the route name from [RouteSettings].
typedef RouteNameExtractor = String? Function(RouteSettings settings);

/// Signature of a function that filters out untracked routes.
typedef RouteFilter = bool Function(Route<dynamic>? route);

/// Default implementation of [RouteNameExtractor].
String? defaultRouteNameExtractor(RouteSettings settings) => settings.name;

/// Default implementation of [RouteFilter].
bool defaultRouteFilter(Route<dynamic>? route) => route is PageRoute;


/// This is a [NavigatorObserver] that gives a convenient way to tag screen names
/// and send them to UXCam's console via `FlutterUxcam.tagScreenName(screenName)`.
///
/// [FlutterUxcamNavigatorObserver] must be added to the list of [navigator observers](https://api.flutter.dev/flutter/material/MaterialApp/navigatorObservers.html).
/// This is an example for [MaterialApp](https://api.flutter.dev/flutter/material/MaterialApp/navigatorObservers.html),
/// but the integration for [CupertinoApp](https://api.flutter.dev/flutter/cupertino/CupertinoApp/navigatorObservers.html)
/// and [WidgetsApp](https://api.flutter.dev/flutter/widgets/WidgetsApp/navigatorObservers.html) is the same.
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:flutter_uxcam/observer.dart';
///
/// MaterialApp(
///   ...
///   navigatorObservers: [
///     FlutterUxcamNavigatorObserver(),
///   ],
///   ...
/// )
/// ```
///
/// Define [routeNameExtractor] to format captured names differently.
/// The default [defaultRouteNameExtractor] will retrieve the route's name from
/// [RouteSettings]. You can also define [routeFilter] that will filter out routes
/// that are not meant to be captured. By default, [defaultRouteFilter] will
/// remove all routes that are `null`.
///
/// See also:
///   - [UXCam - Tag Screen Name](https://developer.uxcam.com/docs/tag-of-screens)
///   - [Flutter - RouteObserver](https://api.flutter.dev/flutter/widgets/RouteObserver-class.html)
///   - [Flutter - Navigating with arguments](https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments)
class FlutterUxcamNavigatorObserver extends RouteObserver<ModalRoute<dynamic>> {
  FlutterUxcamNavigatorObserver({
    this.routeNameExtractor = defaultRouteNameExtractor,
    this.routeFilter = defaultRouteFilter,
  });

  final RouteNameExtractor routeNameExtractor;
  final RouteFilter routeFilter;

  void _tagRoute(Route<dynamic> route) {
    final String? screenName = routeNameExtractor(route.settings);
    if (screenName != null) {
      FlutterUxcam.tagScreenName(screenName);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (routeFilter(route)) {
      _tagRoute(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && routeFilter(newRoute)) {
      _tagRoute(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null &&
        routeFilter(previousRoute) &&
        routeFilter(route)) {
      _tagRoute(previousRoute);
    }
  }
}
