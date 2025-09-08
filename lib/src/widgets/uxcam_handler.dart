import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/src/models/gesture_handler.dart';
import 'package:flutter_uxcam/src/models/ux_traceable_element.dart';
import 'package:flutter_uxcam/src/widgets/uxcam_app_builder.dart';

/// UXCamHandler is a widget that enables gesture tracking and element inspection
/// for UXCam analytics within its widget subtree.
///
/// Place this widget high in your widget tree (e.g., above MaterialApp or at the root of a screen)
/// to capture and analyze user gestures and UI interactions for all descendant widgets.
///
/// - [child]: The subtree to be tracked for gestures and UI element structure.
/// - [types]: Optionally provide custom widget types to be treated as trackable elements.
///
/// Example usage:
/// ```dart
/// UXCamHandler(
///   child: MaterialApp(
///     home: MyHomePage(),
///   ),
/// )
/// ```
///
/// This widget is intended for use in apps that integrate with UXCam for advanced gesture analytics.
/// It should wrap the part of your app where you want gesture and UI element tracking to occur.
///
/// Note: Only one instance should be used per widget tree scope to avoid duplicate tracking.
/// The widget uses a [Listener] to capture pointer events.
///
/// This is mandatory if want to use smart event feature.

class UXCamHandler extends StatefulWidget {
  const UXCamHandler(
      {Key? key, required this.child, this.types = const []})
      : super(key: key);

  final Widget child;
  final List<Type> types;

  @override
  State<UXCamHandler> createState() => _UXCamHandlerState();
}

class _UXCamHandlerState extends State<UXCamHandler> {
  late GestureHandler gestureHandler;

  @override
  void initState() {
    super.initState();
    gestureHandler = GestureHandler();
    UxTraceableElement.setUserDefinedTypes(widget.types);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: uxcamAppBuilder,
      home: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (details) =>
            _onTappedAt(context, details.localPosition),
        child: widget.child,
      ),
    );
  }

  void _onTappedAt(BuildContext context, Offset position) {
    final result = HitTestResult();
    RendererBinding.instance
        .hitTestInView(result, position, View.of(context).viewId);

    final targetList = result.path
        .where((item) => item is BoxHitTestEntry)
        .map((item) => (item.target as RenderObject).hashCode)
        .toList();

    context.visitChildElements((element) {
      gestureHandler.intialize(position, targetList);
      gestureHandler.inspectElement(element);
      gestureHandler.sendTrackDataFromSummaryTree();
    });
  }
}

/// Deprecated: use [UXCamHandler] instead.
@Deprecated('UXCamGestureHandler is deprecated. Use UXCamHandler instead.')
class UXCamGestureHandler extends UXCamHandler {
  const UXCamGestureHandler({Key? key, required Widget child, List<Type> types = const []})
      : super(key: key, child: child, types: types);
}
