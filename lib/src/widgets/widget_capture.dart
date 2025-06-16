import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class WidgetCapture extends StatefulWidget {
  const WidgetCapture({Key? key, required this.child, this.types = const []})
      : super(key: key);

  final Widget child;
  final List<Type> types;

  @override
  State<WidgetCapture> createState() => _WidgetCaptureState();
}

class _WidgetCaptureState extends State<WidgetCapture> {
  late UxCam uxCam;
  List<Type> knownButtonTypes = [ElevatedButton, TextButton, OutlinedButton];

  @override
  void initState() {
    super.initState();
    uxCam = UxCam();
    knownButtonTypes.addAll(widget.types);
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      context.visitChildElements((child) => _inspectDirectChild(child));
    });
  }

  void _inspectDirectChild(Element element) {
    if (element.widget.runtimeType.toString() == "TextField" ||
        element.widget.runtimeType.toString() == "TextFormField") {
      uxCam.addWidgetDataForTracking(_dataForWidget(element));
    } else if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _inspectButtonChild(_dataForWidget(element), element);
    }
    element.visitChildElements(_inspectDirectChild);
  }

  void _inspectButtonChild(TrackData containingWidget, Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph) {
      final textSpan = renderObject.text;
      if (textSpan is TextSpan) {
        containingWidget.setLabel(extractTextFromSpan(textSpan));
        uxCam.addWidgetDataForTracking(containingWidget);
      }
    }
    element.visitChildElements(
        (element) => _inspectButtonChild(containingWidget, element));
  }

  String extractTextFromSpan(TextSpan span) {
    final buffer = StringBuffer();

    void walkSpan(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null) buffer.write(span.text);
        span.children?.forEach(walkSpan);
      }
    }

    walkSpan(span);
    return buffer.toString();
  }

  TrackData _dataForWidget(Element element) {
    final renderObject = element.renderObject;

    final route = ModalRoute.of(element)?.settings.name ?? "";
    String _uiId = element.widget.key != null
        ? element.widget.key.toString()
        : "$route#${identityHashCode(element).toRadixString(16)}";

    int _uiType = -1;
    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = 1;
    }
    if (element.widget.runtimeType.toString() == "TextField" ||
        element.widget.runtimeType.toString() == "TextFormField") {
      _uiType = 2;
    }

    return TrackData(
      _getRectFromBox(renderObject as RenderBox),
      route,
      uiClass: element.widget.runtimeType.toString(),
      uiId: _uiId,
      uiType: _uiType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {},
      child: widget.child,
    );
  }

  Rect _getRectFromBox(RenderBox renderObject) {
    Offset origin;
    Size size;
    origin = renderObject.localToGlobal(Offset.zero);
    size = renderObject.size;
    return origin & size;
  }
}
