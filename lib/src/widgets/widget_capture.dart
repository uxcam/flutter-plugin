import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class WidgetCapture extends StatefulWidget {
  const WidgetCapture({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<WidgetCapture> createState() => _WidgetCaptureState();
}

class _WidgetCaptureState extends State<WidgetCapture> {
  List<TrackData> _trackedWidgets = [];
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      _trackedWidgets.clear();
      context.visitChildElements(_inspectDirectChild);
    });
  }

  void _inspectDirectChild(Element element) {
    if (element.widget is ElevatedButton || element.widget is InkWell) {
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

      //elevated button was found. check if it has a text label
      String? textLabel;
      element.visitChildElements((element) {
        textLabel = getTextLabelIfExists(element);
      });

      final route = ModalRoute.of(element)?.settings.name ?? "";
      String _uiId = element.widget.key != null
          ? element.widget.key.toString()
          : "$route#${identityHashCode(widget)}";

      _trackedWidgets.add(TrackData(origin, size, route,
          uiValue: textLabel,
          uiClass: element.widget.runtimeType.toString(),
          uiId: _uiId,
          uiType: getUiType(element)));

      return;
    }
    element.visitChildElements(_inspectDirectChild);
  }

  int getUiType(Element element) {
    if (element.widget is ElevatedButton ||
        element.widget is InkWell ||
        element.widget is GestureDetector ||
        element.widget is FloatingActionButton) {
      return 1;
    } else if (element.widget is TextField || element.widget is TextFormField) {
      return 2;
    }
    return -1;
  }

  String? getTextLabelIfExists(Element element) {
    if (element.widget is Text) {
      final Text textWidget = element.widget as Text;
      return textWidget.data ?? textWidget.textSpan?.toPlainText();
    }

    String? result;
    element.visitChildElements((child) {
      result ??= getTextLabelIfExists(child);
    });
    return result;
  }

  TrackData? _getWidgetFromCoordinates(Offset position) {
    TrackData? target;
    _trackedWidgets.forEach((data) {
      final bound = data.origin & data.size;
      if (bound.contains(position)) {
        target = data;
      }
    });
    return target;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final _tapCoordinates = event.position;
        final data = _getWidgetFromCoordinates(_tapCoordinates);
        data?.showAnalyticsInfo();
      },
      child: widget.child,
    );
  }
}
