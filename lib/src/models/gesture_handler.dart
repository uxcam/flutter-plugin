import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';
import 'package:flutter_uxcam/src/models/ux_traceable_element.dart';

class GestureHandler {
  Offset position = Offset.zero;
  String _topRoute = "/";

  List<SummaryTree> summaryTreeByRoute = [];

  final UxTraceableElement traceableElement = UxTraceableElement();

  void setPosition(Offset position) {
    this.position = position;
  }

  void inspectElement(Element element) {
    summaryTreeByRoute.clear();
    _inspectDirectChild(
        SummaryTree(
          _topRoute,
          element.widget.runtimeType.toString(),
          traceableElement.getUxType(element),
          bound: element.getEffectiveBounds(),
        ),
        element);
    print("object");
  }

  void _inspectDirectChild(SummaryTree parent, Element element) {
    final type = traceableElement.getUxType(element);
    SummaryTree node = parent;
    if (element.isRendered()) {
      if (type == UX_VIEWGROUP) {
        if (!traceableElement.isOverLay(element)) {
          updateTopRoute(ModalRoute.of(element)?.settings.name ?? "");
        }
        try {
          final tree =
              summaryTreeByRoute.firstWhere((tree) => tree.route == _topRoute);
          if (tree.uiClass != element.widget.runtimeType.toString()) {
            node = SummaryTree(
              _topRoute,
              element.widget.runtimeType.toString(),
              UX_VIEWGROUP,
              bound: element.getEffectiveBounds(),
              isViewGroup: true,
            );
            addSubTreeIfInsideBounds(tree, node);
          }
        } on StateError {
          //a new route has appeared, create a new summary tree
          node = SummaryTree(
            _topRoute,
            element.widget.runtimeType.toString(),
            UX_VIEWGROUP,
            bound: element.getEffectiveBounds(),
            isViewGroup: true,
          );
          addTreeIfInsideBounds(node);
        }
      }
      if (type == UX_TEXT || type == UX_IMAGE) {
        final subTree = _inspectNonInteractiveChild(element);
        if (subTree != null) {
          addSubTreeIfInsideBounds(node, subTree);
        }
        return;
      }
      if (type == UX_BUTTON) {
        final subTree = _inspectButtonChild(element);
        if (subTree != null) {
          addSubTreeIfInsideBounds(node, subTree);
        }
        return;
      }
      if (type == UX_FIELD) {
        final subTree = _inspectTextFieldChild(element);
        if (subTree != null) {
          addSubTreeIfInsideBounds(node, subTree);
        }
        return;
      }
      if (type == UX_COMPOUND) {
        final subTree = _inspectInteractiveChild(element);
        if (subTree != null) {
          addSubTreeIfInsideBounds(node, subTree);
        }
        return;
      }
    }
    element.visitChildElements((elem) => _inspectDirectChild(node, elem));
  }

  SummaryTree? _inspectInteractiveChild(Element element) {
    SummaryTree? subTree;
    String label = "";

    void _extractTextFromButton(Element element) {
      if (element.getEffectiveBounds().contains(position)) {
        if (element.widget is Icon) {
          final iconWidget = element.widget as Icon;
          String iconDataString = iconWidget.semanticLabel ?? "";
          if (iconWidget.icon != null) {
            iconDataString =
                "${iconWidget.icon!.fontFamily}-${iconWidget.icon!.codePoint.toRadixString(16)}";
          }
          label = iconDataString;
        } else {
          final renderObject = element.renderObject;
          if (renderObject is RenderParagraph) {
            final textSpan = renderObject.text;
            if (textSpan is TextSpan) {
              label = extractTextFromSpan(textSpan);
            }
          }
        }
      }
      element.visitChildElements((element) => _extractTextFromButton(element));
    }

    final sibling = element.getSibling();

    if (sibling != null) {
      _extractTextFromButton(sibling);
    }

    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      UX_COMPOUND,
      value: label,
      bound: element.getEffectiveBounds(),
    );

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
      UX_FIELD,
      value: hint,
      bound: element.getEffectiveBounds(),
    );
    return subTree;
  }

  SummaryTree? _inspectButtonChild(Element element) {
    SummaryTree? subTree;
    String label = "";

    void _extractTextFromButton(Element element) {
      if (element.getEffectiveBounds().contains(position)) {
        if (element.widget is Icon) {
          final iconWidget = element.widget as Icon;
          String iconDataString = iconWidget.semanticLabel ?? "";
          if (iconWidget.icon != null) {
            iconDataString =
                "${iconWidget.icon!.fontFamily}-${iconWidget.icon!.codePoint.toRadixString(16)}";
          }
          label = iconDataString;
        } else {
          final renderObject = element.renderObject;
          if (renderObject is RenderParagraph) {
            final textSpan = renderObject.text;
            if (textSpan is TextSpan) {
              if (label.isEmpty) {
                label = extractTextFromSpan(textSpan);
              }
            }
          }
        }
      }
      element.visitChildElements((element) => _extractTextFromButton(element));
    }

    _extractTextFromButton(element);
    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      UX_BUTTON,
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
        UX_TEXT,
        value: widget.data ?? "",
        bound: element.getEffectiveBounds(),
      );
    }
    if (element.widget is Image) {
      String imageDataString =
          _extractImageStringRepresentation((element.widget as Image).image) ??
              (element.widget as Image).semanticLabel ??
              "";

      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
          value: imageDataString,
          bound: element.getEffectiveBounds(),
          custom: {
            "content_desc: ": imageDataString,
          });
    }
    if (element.widget is DecoratedBox) {
      final decoration =
          (element.widget as DecoratedBox).decoration as BoxDecoration;
      final _image = decoration.image;
      String imageDataString = "";
      if (_image != null) {
        imageDataString = _extractImageStringRepresentation(_image.image) ?? "";
      }

      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
          value: imageDataString,
          bound: element.getEffectiveBounds(),
          custom: {
            "content_desc: ": imageDataString,
          });
    }
    if (element.widget is Icon) {
      final iconWidget = element.widget as Icon;
      String iconDataString = iconWidget.semanticLabel ?? "";
      if (iconWidget.icon != null) {
        iconDataString =
            "${iconWidget.icon!.fontFamily}-${iconWidget.icon!.codePoint.toRadixString(16)}";
      }
      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
          value: iconDataString,
          bound: element.getEffectiveBounds(),
          custom: {
            "content_desc: ": iconDataString,
          });
    }
    return subTree;
  }

  String? _extractImageStringRepresentation(ImageProvider provider) {
    if (provider is NetworkImage) {
      return provider.url;
    }
    if (provider is AssetImage) {
      return provider.assetName;
    }
    if (provider is FileImage) {
      return provider.file.path;
    }
    return null;
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
      summaryTreeByRoute.removeWhere((tree) => tree.route != _topRoute);
      summaryTreeByRoute.add(tree);
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
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    }
    return hash.toUnsigned(32).toRadixString(16);
    //return input;
  }

  void updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }

  String _generateUIdFromSummaryTree(SummaryTree tree) {
    return tree.uiClass + "_" + tree.value;
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
      final subTree = summaryTree.subTrees.last;
      if (subTree.type == UX_VIEWGROUP) {
        uId += subTree.uiClass + "_";
        if (subTree.subTrees.isEmpty) {
          uId += subTree.uiClass;
          trackData = TrackData(
            subTree.bound,
            route,
            uiValue: subTree.value,
            uiId: formatValueToId(uId),
            uiClass: subTree.uiClass,
            uiType: subTree.type,
          );
        } else {
          final elementTree = subTree.subTrees.last;
          uId += _generateUIdFromSummaryTree(elementTree);
          trackData = TrackData(
            elementTree.bound,
            route,
            uiValue: elementTree.value,
            uiId: formatValueToId(uId),
            uiClass: elementTree.uiClass,
            uiType: elementTree.type,
          );
        }
      } else {
        uId += _generateUIdFromSummaryTree(subTree);
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

}
