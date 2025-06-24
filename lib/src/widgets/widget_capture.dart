import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
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

  List<Type> userDefinedTypes = [];

  int userDefinedCounter = 0;
  int buttonCounter = 0;
  int nonInteractiveCounter = 0;
  int fieldCounter = 0;

  List<Type> knownButtonTypes = [
    ElevatedButton,
    TextButton,
    OutlinedButton,
    GestureDetector,
    InkWell,
    IconButton,
    FloatingActionButton,
  ];

  List<Type> nonInteractiveTypes = [
    Image,
    Text,
    RichText,
    Icon,
  ];

  List<Type> fieldTypes = [
    TextField,
    TextFormField,
  ];

  List<Type> containerTypes = [
    Scaffold,
    ListView,
    SingleChildScrollView,
    GridView,
  ];

  List<Type> overlayTypes = [
    BottomSheet,
    AlertDialog,
  ];

  @override
  void initState() {
    super.initState();
    uxCam = UxCam();
    userDefinedTypes.addAll(widget.types);
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      buttonCounter = 0;
      nonInteractiveCounter = 0;
      uxCam.removeTrackData();
      context.visitChildElements((child) => _inspectDirectChild(child));
    });
  }

  void _inspectDirectChild(Element element) {
    //first capture route information
    if (containerTypes.contains(element.widget.runtimeType)) {
      uxCam.updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
      uxCam.addWidgetDataForTracking(_dataForWidget(element));
    }
    if (overlayTypes.contains(element.widget.runtimeType)) {
      uxCam.updateTopRoute("/overlay");
      uxCam.addWidgetDataForTracking(_dataForWidget(element));
    }

    if (userDefinedTypes.contains(element.widget.runtimeType)) {
    } else if (fieldTypes.contains(element.widget.runtimeType)) {
      _inspectTextFieldChild(element);
    } else if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _inspectButtonChild(_dataForWidget(element), element);
    } else if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      _inspectNonInteractiveChild(element);
    } else {
      element.visitChildElements(_inspectDirectChild);
    }
  }

  void _inspectNonInteractiveChild(Element element) {
    TrackData? trackData;
    if (element.widget is Text) {
      Text widget = element.widget as Text;
      trackData = _dataForWidget(element);
      trackData.setLabel(widget.data ?? "");
      trackData.setId(formatValueToId(widget.data ?? ""));
    }
    if (element.widget is Image || element.widget is Icon) {
      trackData = _dataForWidget(element);
      trackData.setLabel("");
    }
    if (trackData != null) {
      uxCam.addWidgetDataForTracking(trackData);
    }
  }

  void _inspectTextFieldChild(Element element) {
    String hint = "";
    if (element.widget is TextField) {
      final textField = element.widget as TextField;
      hint = textField.decoration?.hintText ?? "";
    }
    TrackData trackData = _dataForWidget(element);
    trackData.setLabel(hint);
    trackData.setId(formatValueToId(hint));
    uxCam.addWidgetDataForTracking(trackData);
  }

  void _inspectButtonChild(TrackData containingWidget, Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph) {
      final textSpan = renderObject.text;
      if (textSpan is TextSpan) {
        final label = extractTextFromSpan(textSpan);
        containingWidget.setLabel(label);
        containingWidget.setId(formatValueToId(label));
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

    String route = uxCam.topRoute;
    String _uiId =
        element.widget.key != null ? element.widget.key.toString() : "";

    int _uiType = -1;
    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = 1;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      _uiType = 2;
    }
    if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      if (element.widget.runtimeType.toString() == "Text" ||
          element.widget.runtimeType.toString() == "RichText") {
        _uiType = 7;
      }
      if (element.widget.runtimeType.toString() == "Image" ||
          element.widget.runtimeType.toString() == "Icon") {
        _uiType = 12;
        _uiId =
            "${route}_${element.widget.runtimeType}_${nonInteractiveCounter}";
        nonInteractiveCounter++;
      }
    }
    if (containerTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
      _uiId = "00";
    }
    if (overlayTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
      _uiId = "10";
    }

    return TrackData(
      element.isRendered()
          ? _getRectFromBox(renderObject as RenderBox)
          : Rect.zero,
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
      onPointerDown: (event) {
        // uxCam.updateTopRoute(ModalRoute.of(context)?.settings.name ?? "/");
      },
      child: widget.child,
    );
  }

  Rect _getRectFromBox(RenderBox renderObject) {
    final translation = renderObject.getTransformTo(null).getTranslation();
    final offset = Offset(translation.x, translation.y);
    final bounds = renderObject.paintBounds.shift(offset);
    return bounds;
  }

  String formatValueToId(String value) {
    return value
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-zA-Z_]'), '')
        .toLowerCase();
  }
}
