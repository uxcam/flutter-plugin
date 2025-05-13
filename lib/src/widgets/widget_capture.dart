import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class WidgetCapture extends StatefulWidget {
  const WidgetCapture({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<WidgetCapture> createState() => _WidgetCaptureState();
}

class _WidgetCaptureState extends State<WidgetCapture> {
  TrackData? _findGestureReceivingWidget(Offset tapCoordinates) {
    TrackData? trackData;
    void _inspectDirectChild(Element element, Offset gestureCoordinates) {
      bool isLeaf = true;

      final renderObject = element.renderObject;
      Offset origin;
      Size size;

      if (renderObject is RenderSliver) {
        //this is a special case for cases when using ListView, GridView or other Sliver-esque widgets
        element.visitChildElements((child) {
          isLeaf = false;
          _inspectDirectChild(child, gestureCoordinates);
        });
      }

      if (renderObject is RenderBox) {
        origin = renderObject.localToGlobal(Offset.zero);
        size = renderObject.size;
      } else {
        origin = Offset.zero;
        size = Size.zero;
      }

      final bound = origin & size;

      if (bound.contains(gestureCoordinates)) {
        element.visitChildElements((child) {
          isLeaf = false;
          _inspectDirectChild(child, gestureCoordinates);
        });

        if (isLeaf) {
          trackData = _dataForWidget(element);
        }
      }
    }

    context.visitChildElements(
        (child) => _inspectDirectChild(child, tapCoordinates));
    return trackData;
  }

  TrackData _dataForWidget(Element element) {
    final renderObject = element.renderObject;
    Offset origin;
    Size size;
    if (renderObject is RenderBox) {
      origin = renderObject.localToGlobal(Offset.zero);
      size = renderObject.size;
    } else {
      origin = Offset.zero;
      size = Size.zero;
    }

    String textLabel = renderObject is RenderParagraph
        ? getTextLabelIfExists(renderObject)
        : "";

    final route = ModalRoute.of(element)?.settings.name ?? "";
    String _uiId = element.widget.key != null
        ? element.widget.key.toString()
        : "$route#${identityHashCode(element).toRadixString(16)}";

    return TrackData(origin, size, route,
        uiValue: textLabel,
        uiClass: element.widget.runtimeType.toString(),
        uiId: _uiId,
        uiType: 1);
  }

  String getTextLabelIfExists(RenderParagraph renderObject) {
    final span = renderObject.text;
    final buffer = StringBuffer();

    void collect(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null) {
          buffer.write(span.text);
        }
        if (span.children != null) {
          for (final child in span.children!) {
            collect(child);
          }
        }
      }
    }

    collect(span);
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final _tapCoordinates = event.position;
        final trackData = _findGestureReceivingWidget(_tapCoordinates);
        if (trackData != null) {
          trackData.showAnalyticsInfo();
        }
      },
      child: widget.child,
    );
  }
}
