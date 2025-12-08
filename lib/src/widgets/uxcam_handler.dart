import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/src/models/gesture_handler.dart';
import 'package:flutter_uxcam/src/models/ux_traceable_element.dart';
import 'package:flutter_uxcam/src/widgets/uxcam_app_builder.dart';

/// @Deprecated Smart events now work automatically via `startWithConfiguration()`.
/// Remove this widget and optionally add `FlutterUxcam.navigatorObserver` to your app.
@Deprecated('Smart events work automatically. Remove UXCamHandler from your widget tree.')
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

@Deprecated('Use smart events instead. Remove this widget entirely.')
class UXCamGestureHandler extends UXCamHandler {
  const UXCamGestureHandler({Key? key, required Widget child, List<Type> types = const []})
      : super(key: key, child: child, types: types);
}
