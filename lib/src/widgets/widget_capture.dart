import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class WidgetCapture extends StatefulWidget {
  const WidgetCapture({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<WidgetCapture> createState() => _WidgetCaptureState();
}

class _WidgetCaptureState extends State<WidgetCapture> {
  List<TrackData> _trackList = [];

  void _scanElementTree(Element element) {
    void _inspectDirectChild(Element element) {
      bool isLeaf = true;

      if (element.renderObject is RenderSliver) {
        //this is a special case for cases when using ListView, GridView or other Sliver-esque widgets
        element.visitChildElements((child) {
          isLeaf = false;
          _inspectDirectChild(child);
        });
      }

      element.visitChildElements((child) {
        isLeaf = false;
        _inspectDirectChild(child);
      });

      if (isLeaf) {
        final field = element.findAncestorWidgetOfExactType<TextField>();
        if (field != null) {
          //_trackList.add(_dataForWidget(field.ele));
        }
      }
    }

    element.visitChildElements((child) => _inspectDirectChild(child));
  }

  TrackData _dataForWidget(Element element) {
    final renderObject = element.renderObject;

    String textLabel = renderObject is RenderParagraph
        ? getTextLabelIfExists(renderObject)
        : "";

    final route = ModalRoute.of(element)?.settings.name ?? "";
    String _uiId = element.widget.key != null
        ? element.widget.key.toString()
        : "$route#${identityHashCode(element).toRadixString(16)}";

    return TrackData(_getRectFromBox(renderObject as RenderBox), route,
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
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      context.visitChildElements(_scanElementTree);
      print("tracked widgets" + _trackList.length.toString());
    });
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
