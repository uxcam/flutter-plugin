import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';
import 'package:flutter_uxcam/src/models/ux_traceable_element.dart';

class GestureHandler {
  Offset position = Offset.zero;
  List<int>? targetHashList;
  String _topRoute = "/";

  SummaryTree? rootTree;

  final UxTraceableElement traceableElement = UxTraceableElement();

  void intialize(Offset position, List<int> target) {
    this.position = position;
    this.targetHashList = target;
  }

  void inspectElement(Element element) {
    rootTree = null;
    _inspectDirectChild(null, element);
  }

  void _inspectDirectChild(SummaryTree? parent, Element element) {
    final type = traceableElement.getUxType(element);
    SummaryTree? node = parent;

    if (type == UX_VIEWGROUP) {
      node = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        UX_VIEWGROUP,
        element.renderObject?.hashCode ?? 0,
        bound: element.getEffectiveBounds(),
        isViewGroup: true,
        isOccluded:
            element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
      );
      if (element.isRendered() &&
          element.targetListContainsElement(targetHashList)) {
        addTreeIfInsideBounds(parent, node);
      }
    }
    if (type == UX_BUTTON) {
      final subTree = _inspectButtonChild(element);
      if (subTree != null) {
        if (element.isRendered() &&
            element.targetListContainsElement(targetHashList)) {
          addTreeIfInsideBounds(node, subTree);
          node = subTree;
        }
      }
    }
    if (type == UX_COMPOUND) {
      final subTree = _inspectInteractiveChild(element);
      if (subTree != null) {
        if (element.isRendered() &&
            element.targetListContainsElement(targetHashList)) {
          addTreeIfInsideBounds(node, subTree);
          node = subTree;
        }
      }
    }

    if (type == UX_TEXT || type == UX_IMAGE || type == UX_DECOR) {
      final subTree = _inspectNonInteractiveChild(element);
      if (subTree != null) {
        if (element.isRendered()) {
          if (node?.type == UX_BUTTON) {
            addTreeIfInsideBounds(node, subTree, alwaysAdd: true);
          } else {
            if (element.targetListContainsElement(targetHashList)) {
              addTreeIfInsideBounds(node, subTree);
            } else {
              if ((targetHashList?.contains(node.hashCode) ?? false) &&
                  subTree.bound.contains(position)) {
                /// this is a special case. Consider the scenario: Stack(children:[Image, InkWell])
                /// if InkWell(or any other button type) covers the entire Stack and does not have any children(transparent),
                /// and the user taps the Image, they will think that they tapped the Image, but in reality, they tapped the InkWell.
                /// so in order to show the Image information in the dashboard instead of the transparent InkWell which has no relevant information,
                /// we need this check.
                addTreeIfInsideBounds(node, subTree);
              }
            }
          }
        }
        if (type == UX_TEXT || type == UX_IMAGE) {
          return;
        }
      }
    }
    if (type == UX_FIELD) {
      final subTree = _inspectTextFieldChild(element);
      if (subTree != null) {
        if (element.isRendered() &&
            element.targetListContainsElement(targetHashList)) {
          addTreeIfInsideBounds(node, subTree);
        }
      }
      return;
    }
    element.visitChildElements((elem) => _inspectDirectChild(node, elem));
  }

  SummaryTree? _inspectInteractiveChild(Element element) {
    SummaryTree? subTree;
    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      UX_COMPOUND,
      element.renderObject?.hashCode ?? 0,
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
    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      UX_FIELD,
      element.renderObject?.hashCode ?? 0,
      value: hint,
      bound: element.getEffectiveBounds(),
    );
    return subTree;
  }

  SummaryTree? _inspectButtonChild(Element element) {
    SummaryTree? subTree;
    subTree = SummaryTree(
      ModalRoute.of(element)?.settings.name ?? "",
      element.widget.runtimeType.toString(),
      UX_BUTTON,
      element.renderObject?.hashCode ?? 0,
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
        element.renderObject?.hashCode ?? 0,
        value: widget.data ?? "",
        bound: element.getEffectiveBounds(),
        isOccluded:
            element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
      );
    }
    if (element.widget is RichText) {
      RichText widget = element.widget as RichText;
      if (widget.text is TextSpan) {
        subTree = SummaryTree(
          ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(),
          UX_TEXT,
          element.renderObject?.hashCode ?? 0,
          value: extractTextFromSpan(widget.text as TextSpan),
          bound: element.getEffectiveBounds(),
          isOccluded:
              element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
        );
      }
    }
    if (element.widget is Image) {
      String imageDataString =
          extractImagePath((element.widget as Image).image.toString()) ?? "";

      subTree = SummaryTree(
          ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(),
          UX_IMAGE,
          element.renderObject?.hashCode ?? 0,
          value: imageDataString,
          bound: element.getEffectiveBounds(),
          isOccluded:
              element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
          custom: {
            "content_desc: ": imageDataString,
          });
    }
    if (element.widget is DecoratedBox) {
      subTree = SummaryTree(
          ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(),
          UX_IMAGE,
          element.renderObject?.hashCode ?? 0,
          value: _extractImageStringRepresentation(element),
          bound: element.getEffectiveBounds(),
          isOccluded:
              element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
          custom: {
            "content_desc: ": _extractImageStringRepresentation(element),
          });
    }
    if (element.widget is Icon) {
      final iconWidget = element.widget as Icon;
      String iconDataString = iconWidget.semanticLabel ?? "";
      if (iconWidget.icon != null) {
        iconDataString =
            "${iconWidget.icon!.fontFamily}-${iconWidget.icon!.codePoint.toRadixString(16)}";
      }
      subTree = SummaryTree(
          ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(),
          UX_IMAGE,
          element.renderObject?.hashCode ?? 0,
          value: iconDataString,
          bound: element.getEffectiveBounds(),
          isOccluded:
              element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
          custom: {
            "content_desc: ": iconDataString,
          });
    }
    return subTree;
  }

  String? extractImagePath(String input) {
    final regex = RegExp(r'"([^"]+)"');
    final match = regex.firstMatch(input);
    return match?.group(1) != "null" ? match?.group(1) : null;
  }

  String _extractImageStringRepresentation(Element element) {
    String imageDataString = "";
    if ((element.widget as DecoratedBox).decoration is BoxDecoration) {
      final decoration =
          (element.widget as DecoratedBox).decoration as BoxDecoration;
      final _image = decoration.image;
      if (_image != null) {
        imageDataString = extractImagePath(_image.image.toString()) ?? "";
      }
      if (imageDataString.isEmpty) {
        final _shape = decoration.shape;
        if (_shape != BoxShape.rectangle) {
          imageDataString = "";
        }
      }
    } else {
      if ((element.widget as DecoratedBox).decoration is ShapeDecoration) {
        final decoration =
            (element.widget as DecoratedBox).decoration as ShapeDecoration;
        final _shape = decoration.shape;
        imageDataString = "";
      }
    }
    return imageDataString;
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

  void addTreeIfInsideBounds(SummaryTree? root, SummaryTree tree,
      {bool alwaysAdd = false}) {
    if (root == null) {
      if (tree.type == UX_VIEWGROUP) {
        //there is a case where the absolute root of the summary tree is not a view group. ex. when long pressing/ holding a textfield,
        //a context menu will appear, which is not part of the widget tree. In that case we have to prevent such a widget as the absolute root can only be a view group.
        rootTree = tree;
      }
    } else {
      bool isInside = false;
      isInside = tree.bound.contains(position);
      // If not inside, check a circle of points (n points in equal interval around a radius)
      if (!isInside) {
        const double radius = 10.0;
        const int numPoints = 8;
        final List<Offset> offsets = List.generate(numPoints, (i) {
          final double angle = (2 * pi * i) / numPoints;
          return Offset(
            position.dx + radius * cos(angle),
            position.dy + radius * sin(angle),
          );
        });
        for (final offset in offsets) {
          if (tree.bound.contains(offset)) {
            isInside = true;
            break;
          }
        }
      }
      if (isInside || alwaysAdd) {
        root.subTrees = [
          ...root.subTrees,
          tree,
        ];
      }
    }
  }

  String formatValueToPseudoId(String value) {
    final input = value
        .replaceAll(' ', '')
        // .replaceAll(RegExp(r'[^a-zA-Z_]'), '')
        .toLowerCase();
    return input;
  }

  String generateStringHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    }
    return ":" + hash.toUnsigned(32).toRadixString(16);
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
    List<String> uIdPath = [];
    List<int> typePath = [];
    SummaryTree? summaryTree = rootTree;
    List<SummaryTree> leaves = [];

    String route = summaryTree!.route;
    if (route == "/") {
      route = "root";
    }

    void traverseTree(SummaryTree tree) {
      uIdPath.add(tree.uiClass);
      typePath.add(tree.type);
      if (tree.subTrees.isEmpty) {
        leaves.add(tree);
      }
      for (SummaryTree tree in tree.subTrees.reversed) {
        traverseTree(tree);
      }
    }

    traverseTree(summaryTree);

    SummaryTree? leaf;
    if (leaves.isNotEmpty) {
      try {
        leaf = leaves.firstWhere((node) {
          return node.bound.contains(position);
        });
      } on StateError {
        leaf = leaves[0];
      }
    }

    if (leaf != null) {
      String uId = uIdPath.join("#") + "#" + leaf.uiClass;
      int effectiveType = UxTraceableElement.parseStringIdToGetType(
          typePath.join("#") + "#" + leaf.type.toString());
      uId += "#" + formatValueToPseudoId(leaf.value);

      trackData = TrackData(
        leaf.bound,
        leaf.route,
        uiValue: leaf.isOccluded ? "" : leaf.value,
        //uiId: uId,
        uiId: leaf.isOccluded ? "" : leaf.route + generateStringHash(uId),
        uiClass: leaf.isOccluded ? "" : leaf.uiClass,
        uiType: leaf.isOccluded ? UX_UNKOWN : effectiveType,
        isSensitive: leaf.isOccluded,
      );

      print("messagex:" + trackData.toString());
      FlutterUxcam.appendGestureContent(position, trackData);
    }
  }
}
