import 'package:flutter/material.dart';

/// @deprecated Smart events now work automatically via `startWithConfiguration()`.
/// This widget is kept for backwards compatibility but does nothing internally.
/// You can safely remove this widget from your widget tree.
@Deprecated(
    'Smart events work automatically. Remove UXCamHandler from your widget tree.')
class UXCamHandler extends StatelessWidget {
  const UXCamHandler({Key? key, required this.child, this.types = const []})
      : super(key: key);

  final Widget child;
  final List<Type> types;

  @override
  Widget build(BuildContext context) {
    // This widget does nothing - smart events are handled automatically
    return child;
  }
}

/// @deprecated Smart events now work automatically via `startWithConfiguration()`.
/// This widget is kept for backwards compatibility but does nothing internally.
/// You can safely remove this widget from your widget tree.
@Deprecated(
    'Smart events work automatically. Remove UXCamGestureHandler from your widget tree.')
class UXCamGestureHandler extends StatelessWidget {
  const UXCamGestureHandler(
      {Key? key, required this.child, this.types = const []})
      : super(key: key);

  final Widget child;
  final List<Type> types;

  @override
  Widget build(BuildContext context) {
    // This widget does nothing - smart events are handled automatically
    return child;
  }
}
