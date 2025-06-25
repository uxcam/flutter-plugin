import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class GestureHandler {
  List<TrackData> _trackList = [];
  String _topRoute = "/";
  String get topRoute => _topRoute;

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

  List<Type> interactiveTypes = [
    Radio,
    Slider,
    Switch,
    Checkbox,
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

  void inspectElement(Element element) {
    buttonCounter = 0;
    nonInteractiveCounter = 0;
    removeTrackData();
    _inspectDirectChild(element);
    _generateCompoundButtonIdFromSiblings();
  }

  void _inspectDirectChild(Element element) {
    //first capture route information
    if (containerTypes.contains(element.widget.runtimeType)) {
      updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
      addWidgetDataForTracking(_dataForWidget(element));
    }
    if (overlayTypes.contains(element.widget.runtimeType)) {
      updateTopRoute("/overlay");
      addWidgetDataForTracking(_dataForWidget(element));
    }

    if (userDefinedTypes.contains(element.widget.runtimeType)) {
    } else if (fieldTypes.contains(element.widget.runtimeType)) {
      _inspectTextFieldChild(element);
    } else if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _inspectButtonChild(_dataForWidget(element), element);
    } else if (_isInteractive(element)) {
      _inspectInteractiveChild(element);
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
    if (element.widget is Image) {
      String? label = (element.widget as Image).semanticLabel;
      trackData = _dataForWidget(element);
      trackData.setLabel(label ?? "");
      trackData.addCustomProperty({
        "content_desc: ": label ?? "",
      });
    }
    if (element.widget is Icon) {
      String? label = (element.widget as Icon).semanticLabel;
      trackData = _dataForWidget(element);
      trackData.setLabel(label ?? "");
      trackData.addCustomProperty({
        "content_desc: ": label ?? "",
      });
    }

    if (trackData != null) {
      addWidgetDataForTracking(trackData);
    }
  }

  void _inspectInteractiveChild(Element element) {
    TrackData? trackData;
    if (element.widget is Radio) {
      Radio widget = element.widget as Radio;
      trackData = _dataForWidget(element);
      trackData.setLabel((widget.value ?? false).toString());
    }
    if (element.widget is Slider) {
      Slider widget = element.widget as Slider;
      trackData = _dataForWidget(element);
      trackData.setLabel(widget.value.toString());
    }
    if (element.widget is Checkbox) {
      Checkbox widget = element.widget as Checkbox;
      trackData = _dataForWidget(element);
      trackData.setLabel(widget.value.toString());
    }
    if (element.widget is Switch) {
      Switch widget = element.widget as Switch;
      trackData = _dataForWidget(element);
      trackData.setLabel(widget.value.toString());
    }

    if (trackData != null) {
      trackData.setId("${trackData.depth}");
      addWidgetDataForTracking(trackData);
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
    addWidgetDataForTracking(trackData);
  }

  void _inspectButtonChild(TrackData containingWidget, Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph) {
      final textSpan = renderObject.text;
      if (textSpan is TextSpan) {
        final label = extractTextFromSpan(textSpan);
        containingWidget.setLabel(label);
        containingWidget.setId(formatValueToId(label));
        addWidgetDataForTracking(containingWidget);
      }
      addWidgetDataForTracking(containingWidget);
    }
    addWidgetDataForTracking(containingWidget);
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

    bool isViewGroup = false;
    String route = topRoute;
    String _uiId =
        element.widget.key != null ? element.widget.key.toString() : "";
    String _uiClass = element.widget.runtimeType.toString();
    int _uiType = -1;
    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = 1;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      _uiType = 2;
    }
    if (_isInteractive(element)) {
      _uiType = 3;
      if (element.widget.runtimeType.toString().startsWith("Radio")) {
        _uiClass = "Radio";
      }
    }
    if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      if (element.widget.runtimeType.toString() == "Text" ||
          element.widget.runtimeType.toString() == "RichText") {
        _uiType = 7;
      }
      if (element.widget.runtimeType.toString() == "Image" ||
          element.widget.runtimeType.toString() == "Icon") {
        _uiType = 12;
        _uiId = "${nonInteractiveCounter}";
        nonInteractiveCounter++;
      }
    }

    if (containerTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
      _uiId = "${element.widget.runtimeType.toString()}_00";
      isViewGroup = true;
    }
    if (overlayTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
      _uiId = "${element.widget.runtimeType.toString()}_10";
      isViewGroup = true;
    }

    return TrackData(
      element.isRendered()
          ? _getRectFromBox(renderObject as RenderBox)
          : Rect.zero,
      route,
      uiClass: _uiClass,
      uiId: _uiId,
      uiType: _uiType,
      isViewGroup: isViewGroup,
      depth: element.depth,
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

  void addWidgetDataForTracking(TrackData data) {
    final id = data.uiId ?? "";
    _trackList.removeWhere((item) => item.uiId == id);
    _trackList.add(data);
  }

  void updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }

  void removeTrackData() {
    _trackList.clear();
  }

  void notifyTrackDataAt(Offset offset) {
    TrackData? _trackData;
    try {
      _trackData = _trackList.lastWhere((data) {
        return data.bound.contains(offset);
      });
    } catch (e) {}

    if (_trackData != null) {
      if (_trackData.route != _topRoute) {
        return;
      }

      if (_trackData.route == "/") {
        _trackData.route = "root";
        if (_trackData.uiId != null) {
          _trackData.uiId = "root_${_trackData.uiId!}";
        }
      } else {
        _trackData.uiId =
            "${_trackData.route.replaceAll(' ', '')}_${_trackData.uiId!}";
        if (_trackData.uiId!.startsWith("/")) {
          _trackData.uiId = _trackData.uiId!.substring(1);
        }
      }
      FlutterUxcam.appendGestureContent(
        offset,
        _trackData,
      );
    }
  }

  bool _isInteractive(Element element) {
    final isPresent = interactiveTypes.contains(element.widget.runtimeType);
    if (isPresent) {
      return true;
    } else {
      //Radio types require extra processing
      if (element.widget.runtimeType.toString().startsWith("Radio")) {
        return true;
      }
    }
    return false;
  }

  void _generateCompoundButtonIdFromSiblings() {
    final compoundData = _trackList.where((data) {
      return data.uiType == 3;
    }).toList();

    for (var data in compoundData) {
      try {
        final requiredDepth = data.depth;
        final compoundId = data.uiId ?? "";
        final sibling = _trackList.firstWhere(
            (data) => data.depth == requiredDepth && data.uiId != compoundId);
        data.uiId = "${data.uiClass}_${sibling.uiValue}";
      } on StateError {}
    }
    print("object");
  }
}
