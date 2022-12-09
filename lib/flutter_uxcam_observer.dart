import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// Here using NavigatorObserver instead of [RouteObserver] because
/// [RouteObserver] only works for Navigator 1.0 and will log nothing
/// or perform no calls in case of Navigator 2.0.
class FlutterUxcamNavigatorObserver extends NavigatorObserver {
  /// Using this approach as we need to keep track of screens
  /// before this one and keep track of screens previous to the
  /// current one.
  List<String> screenNames = [];

  /// Using this to chech for and store latest Screen Name
  String taggingScreen = '';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    /// This line of code is required as there are scenarios where we have
    /// routing like in popup menu but it is not handled by routing in 
    /// [onGenerateRoute].
    if (route.settings.name != null) { 
      screenNames.add(route.settings.name!);
      setAndTaggingScreenName();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    screenNames.remove(newRoute?.settings.name);
    setAndTaggingScreenName();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    screenNames.remove(route.settings.name);
    setAndTaggingScreenName();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    screenNames.remove(route.settings.name);
    setAndTaggingScreenName();
    super.didRemove(route, previousRoute);
  }

  /// This function will just perform operation for setting [taggingScreen] and
  /// depeding on the value of  [taggingScreen] will either discard or perform
  /// [FlutterUxcam.tagScreenName] operation.
  void setAndTaggingScreenName() {
    taggingScreen = screenNames.isNotEmpty ? screenNames.last : '';
    if (taggingScreen.isNotEmpty) {
      FlutterUxcam.tagScreenName(taggingScreen);
    }
  }
}
