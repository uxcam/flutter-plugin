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
    if (type == 1) {
      final subTree = _inspectButtonChild(element);
      if (subTree != null) {
        addSubTreeIfInsideBounds(node, subTree);
      }
      return;
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

  SummaryTree? _inspectInteractiveChild(Element element) {
    SummaryTree? subTree;
    String label = "";

    void _extractTextFromButton(Element element) {
      final renderObject = element.renderObject;
      if (renderObject is RenderParagraph) {
        final textSpan = renderObject.text;
        if (textSpan is TextSpan) {
          label = extractTextFromSpan(textSpan);
        }
      }
      element.visitChildElements((element) => _extractTextFromButton(element));
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
    }
    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      2,
      value: hint,
      bound: element.getEffectiveBounds(),
    );
    return subTree;
  }

  SummaryTree? _inspectButtonChild(Element element) {
    SummaryTree? subTree;
    String label = "";

    void _extractTextFromButton(Element element) {
      final renderObject = element.renderObject;
      if (renderObject is RenderParagraph) {
        final textSpan = renderObject.text;
        if (textSpan is TextSpan) {
          label = extractTextFromSpan(textSpan);
        }
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

  void addTreeIfInsideBounds(SummaryTree tree) {
    if (tree.bound.contains(position)) {
      summaryTreeByRoute.add(tree);
    }
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
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    }
    return hash.toUnsigned(32).toRadixString(16);
  }

  void updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }

  void sendTrackDataFromSummaryTree() {
    TrackData? trackData;
    String uId = "";
    final summaryTree = summaryTreeByRoute.last;
    String route = summaryTree.route;
    if (route == "/") {
      route = "root";
    }
    uId += route + "_";
    if (summaryTree.subTrees.isEmpty) {
      uId += summaryTree.uiClass;
      trackData = TrackData(
        summaryTree.bound,
        route,
        uiValue: "",
        uiId: formatValueToId(uId),
        uiClass: summaryTree.uiClass,
        uiType: summaryTree.type,
      );
    } else {
      final subTree = summaryTree.subTrees.first;
      if (subTree.type == 5) {
        uId += subTree.uiClass + "_";
        final elementTree = subTree.subTrees.first;
        uId += elementTree.uiClass + "_" + elementTree.value;
        trackData = TrackData(
          elementTree.bound,
          route,
          uiValue: elementTree.value,
          uiId: formatValueToId(uId),
          uiClass: elementTree.uiClass,
          uiType: elementTree.type,
        );
      } else {
        uId += subTree.uiClass + "_" + subTree.value;
        trackData = TrackData(
          subTree.bound,
          route,
          uiValue: subTree.value,
          uiId: formatValueToId(uId),
          uiClass: subTree.uiClass,
          uiType: subTree.type,
        );
      }
    }

    print("messagex:" + trackData.toString());
    FlutterUxcam.appendGestureContent(position, trackData);
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
