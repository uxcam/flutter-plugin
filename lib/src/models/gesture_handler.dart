import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class GestureHandler {
  List<TrackData> _trackList = [];
  String _topRoute = "/";

  List<Type> userDefinedTypes = [];

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

  List<Type> containerTypes = [Scaffold];

  List<Type> overlayTypes = [
    BottomSheet,
    Dialog,
  ];

  void inspectDirectChild(Element element) {
    if (containerTypes.contains(element.widget.runtimeType)) {
      final trackData = _dataForWidget(element);

      addWidgetDataForTracking(trackData);
    }

    if (overlayTypes.contains(element.widget.runtimeType)) {
      // Handle overlays like BottomSheet or Dialog
      final trackData = _dataForWidget(element);
      addWidgetDataForTracking(trackData);
      updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
    }

    if (userDefinedTypes.contains(element.widget.runtimeType)) {
    } else if (fieldTypes.contains(element.widget.runtimeType)) {
      _inspectTextFieldChild(element);
    } else if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _inspectButtonChild(_dataForWidget(element), element);
    } else if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      _inspectNonInteractiveChild(element);
    } else {
      element.visitChildElements(inspectDirectChild);
    }
  }

  void _inspectNonInteractiveChild(Element element) {
    TrackData? trackData;
    if (element.widget is Text) {
      Text widget = element.widget as Text;
      trackData = _dataForWidget(element);
      trackData.setLabel(widget.data ?? "");
    }
    if (element.widget is Image || element.widget is Icon) {
      trackData = _dataForWidget(element);
      trackData.setLabel("");
    }
    if (trackData != null) {
      addWidgetDataForTracking(trackData);
      updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
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
    addWidgetDataForTracking(trackData);
    updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
  }

  void _inspectButtonChild(TrackData containingWidget, Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph) {
      final textSpan = renderObject.text;
      if (textSpan is TextSpan) {
        containingWidget.setLabel(extractTextFromSpan(textSpan));
        addWidgetDataForTracking(containingWidget);
        updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
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

    String route = ModalRoute.of(element)?.settings.name ?? "";
    if (route == "") route = "/";
    String _uiId = element.widget.key != null
        ? element.widget.key.toString()
        : "${route}_${element.widget.runtimeType}_${identityHashCode(element).toRadixString(16)}";

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
      }
    }
    if (containerTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
    }

    return TrackData(
      _getRectFromBox(renderObject as RenderBox),
      route,
      uiClass: element.widget.runtimeType.toString(),
      uiId: _uiId,
      uiType: _uiType,
    );
  }

  Rect _getRectFromBox(RenderBox renderObject) {
    final translation = renderObject.getTransformTo(null).getTranslation();
    final offset = Offset(translation.x, translation.y);
    final bounds = renderObject.paintBounds.shift(offset);
    return bounds;
  }

  void addWidgetDataForTracking(TrackData data) {
    final id = data.uiId ?? "";
    _trackList.removeWhere((item) => item.uiId == id);
    _trackList.add(data);
  }

  void updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }

  void notifyTrackDataAt(Offset offset) {
    TrackData? _trackData;
    try {
      _trackData = _trackList.lastWhere((data) {
        return data.bound.contains(offset);
      });
    } catch (e) {}

    print("messagex:" + offset.toString());
    print("messagex:" + _trackList.toString());

    if (_trackData != null) {
      if (_trackData.route != _topRoute) {
        return;
      }

      if (_trackData.route == "/") {
        _trackData.route = "root";
        if (_trackData.uiId != null) {
          _trackData.uiId =
              "root" + _trackData.uiId!.substring(1, _trackData.uiId!.length);
        }
      }
      if (_trackData.uiId != null && _trackData.uiId!.startsWith("/")) {
        _trackData.uiId =
            _trackData.uiId!.substring(1, _trackData.uiId!.length);
      }
      FlutterUxcam.appendGestureContent(offset, _trackData);
    }
  }
}
