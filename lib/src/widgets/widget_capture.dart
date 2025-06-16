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
  List<TrackData> _trackList = [];
  List<Type> knownButtonTypes = [ElevatedButton, TextButton, OutlinedButton];

  @override
  void initState() {
    super.initState();
    knownButtonTypes.addAll(widget.types);
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      context.visitChildElements((child) => _inspectDirectChild(child));
    });
  }

  void _inspectDirectChild(Element element) {
    if (element.widget.runtimeType is TextField ||
        element.widget.runtimeType is TextFormField) {
      _trackList.add(_dataForWidget(element));
    } else if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _inspectButtonChild(element);
    }
    element.visitChildElements(_inspectDirectChild);
  }

  void _inspectButtonChild(Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph) {
      final textSpan = renderObject.text;
      if (textSpan is TextSpan) {
        TrackData data = _dataForWidget(element);
        data.setLabel(extractTextFromSpan(textSpan));
        _trackList.add(data);
      }
    }
    element.visitChildElements(_inspectButtonChild);
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

    return TrackData(_getRectFromBox(renderObject as RenderBox), route,
        uiClass: element.widget.runtimeType.toString(), uiId: _uiId, uiType: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        TrackData? _trackData;
        try {
          _trackData = _trackList.firstWhere((data) {
            return data.bound.contains(event.position);
          });
          FlutterUxcam.appendGestureContent(event.position, _trackData);
        } on StateError catch (_) {}
      },
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
