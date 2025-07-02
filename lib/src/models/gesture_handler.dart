import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class GestureHandler {
  Offset position = Offset.zero;
  String _topRoute = "/";
  String get topRoute => _topRoute;

  List<SummaryTree> summaryTreeByRoute = [];

  int userDefinedCounter = 0;
  int buttonCounter = 0;
  int nonInteractiveCounter = 0;
  int fieldCounter = 0;
  int formFieldCounter = 0;

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
  ];

  List<Type> scrollingContainerTypes = [
    ListView,
    SingleChildScrollView,
    GridView,
  ];

  List<Type> containerTypes = [
    Scaffold,
  ];

  List<Type> overlayTypes = [
    BottomSheet,
    AlertDialog,
  ];

  void setPosition(Offset position) {
    this.position = position;
  }

  void inspectElement(Element element) {
    summaryTreeByRoute.clear();
    _inspectDirectChild(
        SummaryTree(
          _topRoute,
          element.widget.runtimeType.toString(),
          getUxType(element),
          bound: element.getEffectiveBounds(),
        ),
        element);
    print("object");
  }

  void _inspectDirectChild(SummaryTree parent, Element element) {
    final type = getUxType(element);
    SummaryTree node = parent;
    if (type == 5) {
      updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
      try {
        final tree =
            summaryTreeByRoute.firstWhere((tree) => tree.route == _topRoute);
        if (tree.uiClass != element.widget.runtimeType.toString()) {
          node = SummaryTree(
            _topRoute,
            element.widget.runtimeType.toString(),
            5,
            bound: element.getEffectiveBounds(),
            isViewGroup: true,
          );
          tree.subTrees = [...tree.subTrees, node];
        }
      } on StateError {
        //a new route has appeared, create a new summary tree
        node = SummaryTree(
          _topRoute,
          element.widget.runtimeType.toString(),
          5,
          bound: element.getEffectiveBounds(),
          isViewGroup: true,
        );
        addTreeIfInsideBounds(node);
      }
    }
    if (type == 7 || type == 12) {
      final subTree = _inspectNonInteractiveChild(element);
      if (subTree != null) {
        addSubTreeIfInsideBounds(node, subTree);
      }
      return;
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
      element.visitChildElements((child) {
        // if (child.widget is OccludeWrapper) {
        //   // Do not recurse into this child or its subtree
        //   return;
        // }
        // Recursively visit this child's subtree
        _inspectDirectChild(child);
      });
    }
    if (type == 2) {
      final subTree = _inspectTextFieldChild(element);
      if (subTree != null) {
        addSubTreeIfInsideBounds(node, subTree);
      }
      return;
    }
    if (type == 3) {
      final subTree = _inspectInteractiveChild(element);
      if (subTree != null) {
        addSubTreeIfInsideBounds(node, subTree);
      }
      return;
    }
    element.visitChildElements((elem) => _inspectDirectChild(node, elem));
  }

  void _inspectNonInteractiveChild(Element element) {
    TrackData? trackData;
    if (element.widget is Text) {
      Text widget = element.widget as Text;
      trackData = _dataForWidget(element);
      trackData?.setLabel(widget.data ?? "");
      trackData?.setId(formatValueToId(widget.data ?? ""));
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

    final sibling = element.getSibling();

    if (sibling != null) {
      _extractTextFromButton(sibling);
    }

    if (element.widget is Radio) {
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        3,
        value: label,
        bound: element.getEffectiveBounds(),
      );
    }
    if (element.widget is Slider) {
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        3,
        value: label,
        bound: element.getEffectiveBounds(),
      );
    }
    if (element.widget is Checkbox) {
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        3,
        value: label,
        bound: element.getEffectiveBounds(),
      );
    }
    if (element.widget is Switch) {
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        3,
        value: label,
        bound: element.getEffectiveBounds(),
      );
    }

    return subTree;
  }

  SummaryTree? _inspectTextFieldChild(Element element) {
    SummaryTree? subTree;
    String hint = "";
    if (element.widget is TextField) {
      final textField = element.widget as TextField;
      hint = textField.decoration?.hintText ??
          textField.decoration?.labelText ??
          "";
    } else if (element.widget is TextFormField) {
      String? hintFromDescendant;
      element.visitChildElements((child) {
        if (child.widget is TextField) {
          final textField = child.widget as TextField;
          hintFromDescendant =
              textField.decoration?.hintText ?? textField.decoration?.labelText;
        } else {
          child.visitChildElements((child) {
            if (child.widget is TextField) {
              final textField = child.widget as TextField;
              hintFromDescendant = textField.decoration?.hintText ??
                  textField.decoration?.labelText;
            }
          });
        }
        ;
      });
      hint = hintFromDescendant ?? "";
    }

    TrackData? trackData = _dataForWidget(element);
    trackData?.setLabel(hint);
    if (hint != "") {
      trackData?.setId(formatValueToId(hint));
    }
    addWidgetDataForTracking(trackData);
  }

  void _inspectButtonChild(TrackData? containingWidget, Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph) {
      final textSpan = renderObject.text;
      if (textSpan is TextSpan) {
        final label = extractTextFromSpan(textSpan);
        containingWidget?.setLabel(label);
        // containingWidget?.setId(formatValueToId(label));
      }
      element.visitChildElements((element) => _extractTextFromButton(element));
    }

    _extractTextFromButton(element);
    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      1,
      value: label,
      bound: element.getEffectiveBounds(),
    );

    return subTree;
  }

  SummaryTree? _inspectNonInteractiveChild(Element element) {
    SummaryTree? subTree;
    if (element.widget is Text) {
      Text widget = element.widget as Text;
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        7,
        value: widget.data ?? "",
        bound: element.getEffectiveBounds(),
      );
    }
    if (element.widget is Image) {
      String? label = (element.widget as Image).semanticLabel;
      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), 7,
          value: (element.widget as Image).semanticLabel ?? "",
          bound: element.getEffectiveBounds(),
          custom: {
            "content_desc: ": label ?? "",
          });
    }
    if (element.widget is Icon) {
      String? label = (element.widget as Icon).semanticLabel;
      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), 7,
          value: (element.widget as Icon).semanticLabel ?? "",
          bound: element.getEffectiveBounds(),
          custom: {
            "content_desc: ": label ?? "",
          });
    }
    return subTree;
  }

  int getUxType(Element element) {
    int _uiType = -1;
    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = 1;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      _uiType = 2;
    }
    if (_isInteractive(element)) {
      _uiType = 3;
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

    if (containerTypes.contains(element.widget.runtimeType) ||
        scrollingContainerTypes.contains(element.widget.runtimeType) ||
        overlayTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
    }
    return _uiType;
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

  TrackData? _dataForWidget(Element element) {
    final renderObject = element.renderObject;

    bool isViewGroup = false;
    String route = topRoute;
    String depth = element.depth.toString();
    String _uiId =
        element.widget.key != null ? element.widget.key.toString() : "";
    String _uiClass = element.widget.runtimeType.toString();
    int _uiType = -1;

    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = 1;
      String id = "${knownButtonTypes.hashCode}_${depth.hashCode}";
      _uiId = element.widget.key != null ? element.widget.key.toString() : id;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      _uiType = 2;
      String id = "${fieldTypes.hashCode}_${depth.toString().hashCode}";
      _uiId = element.widget.key != null ? element.widget.key.toString() : id;
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
        String id =
            "${nonInteractiveTypes.hashCode}_${"Text".hashCode}_${depth.hashCode}";
        _uiId = element.widget.key != null ? element.widget.key.toString() : id;
      }
      if (element.widget.runtimeType.toString() == "Image" ||
          element.widget.runtimeType.toString() == "Icon") {
        _uiType = 12;
        String id =
            "${nonInteractiveTypes.hashCode}_${"Image".hashCode}_${depth.hashCode}";
        _uiId = element.widget.key != null ? element.widget.key.toString() : id;
        nonInteractiveCounter++;
      }
    }

    if (containerTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
      _uiId = "${containerTypes.hashCode}_${depth.hashCode}";
      isViewGroup = true;
    }
    if (overlayTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
      _uiId = "${overlayTypes.hashCode}_${depth.hashCode}";
      isViewGroup = true;
    }

    TrackData trackData = TrackData(
      element.isRendered()
          ? _getRectFromBox(renderObject as RenderBox)
          : Rect.zero,
      route,
      uiValue: "",
      uiClass: _uiClass,
      uiType: _uiType,
      uiId: _uiId,
      isViewGroup: isViewGroup,
      depth: element.depth,
      isSensitive: isDescendantOfType(element, OccludeWrapper),
    );

    if (trackData.bound == Rect.zero) {
      // If the element is not rendered, we can skip adding it
      return null;
    }
    return trackData;
  }

  bool isDescendantOfType(Element element, Type targetType) {
    bool found = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget.runtimeType == targetType) {
        found = true;
        return false; // Stop visiting
      }
      return true; // Continue visiting
    });
    return found;
  }

  void addSubTreeIfInsideBounds(SummaryTree root, SummaryTree tree) {
    if (tree.bound.contains(position)) {
      root.subTrees = [
        ...root.subTrees,
        tree,
      ];
    }
  }

  String formatValueToId(String value) {
    final input = value
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-zA-Z_]'), '')
        .toLowerCase();
  }

  void addWidgetDataForTracking(TrackData? data) {
    if (data == null) return;
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

      print("messagex:" + _trackData.toString());

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
}
