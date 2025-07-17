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

  SummaryTree? rootTree;

  final UxTraceableElement traceableElement = UxTraceableElement();

  void setPosition(Offset position) {
    this.position = position;
  }

  void inspectElement(Element element) {
    rootTree = null;
    _inspectDirectChild(null, element);
    print("object");
  }

  bool elementExistsInTree(Element element) {
    return false;
  }

  void _inspectDirectChild(SummaryTree? parent, Element element) {
    final type = traceableElement.getUxType(element);
    SummaryTree? node = parent;
    if (element.isRendered()) {
      if (type == UX_VIEWGROUP) {
        node = SummaryTree(
          ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(),
          UX_VIEWGROUP,
          bound: element.getEffectiveBounds(),
          isViewGroup: true,
          isOccluded:
              element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
        );
        addTreeIfInsideBounds(parent, node);
      }
      if (type == UX_BUTTON) {
        final subTree = _inspectButtonChild(element);
        if (subTree != null) {
          addTreeIfInsideBounds(node, subTree);
          node = subTree;
        }
      }
      if (type == UX_COMPOUND) {
        final subTree = _inspectInteractiveChild(element);
        if (subTree != null) {
          addTreeIfInsideBounds(node, subTree);
          node = subTree;
        }
      }

      if (type == UX_TEXT || type == UX_IMAGE || type == UX_DECOR) {
        final subTree = _inspectNonInteractiveChild(element);
        if (subTree != null) {
          if (subTree.value.isNotEmpty && type != UX_DECOR) {
            addTreeIfInsideBounds(node, subTree);
            print("object");
            return;
          }
        }
      }
      if (type == UX_FIELD) {
        final subTree = _inspectTextFieldChild(element);
        if (subTree != null) {
          addTreeIfInsideBounds(node, subTree);
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

    if (label.isNotEmpty) {
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        UX_COMPOUND,
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
      UX_FIELD,
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

      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
          value: imageDataString,
          bound: element.getEffectiveBounds(),
          isOccluded:
              element.findAncestorWidgetOfExactType<OccludeWrapper>() != null,
          custom: {
            "content_desc: ": imageDataString,
          });
    }
    if (element.widget is DecoratedBox) {
      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
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
      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
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
    return match?.group(1);
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
      final _shape = decoration.shape;
      if (_shape != BoxShape.rectangle) {
        imageDataString = "";
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

  void addTreeIfInsideBounds(SummaryTree? root, SummaryTree tree) {
    if (root == null) {
      rootTree = tree;
    } else {
      bool isInside = tree.bound.contains(position);
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
      if (isInside) {
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
    String uId = "";
    String typePath = "";
    SummaryTree? summaryTree = rootTree;
    String route = summaryTree!.route;

    if (route == "/") {
      route = "root";
    }
    uId += summaryTree.uiClass + "#";
    typePath += "${summaryTree.type}#";

    do {
      SummaryTree subTree;
      if (summaryTree!.subTrees.length == 1) {
        subTree = summaryTree.subTrees.first;
      } else {
        final reversedTrees = summaryTree.subTrees.reversed;
        subTree = reversedTrees.firstWhere((node) {
          return node.value.isNotEmpty;
        }, orElse: () {
          return reversedTrees.first;
        });
      }
      uId += subTree.uiClass + "#";
      typePath += "${subTree.type}#";
      summaryTree = subTree;
    } while (summaryTree.subTrees.isNotEmpty);

    if (summaryTree.subTrees.isEmpty) {
      uId = summaryTree.route + "#" + uId;
      typePath += "${summaryTree.type}";
      int effectiveType = UxTraceableElement.parseStringIdToGetType(typePath);
      uId += "#" + formatValueToPseudoId(summaryTree.value);

      trackData = TrackData(
        summaryTree.bound,
        summaryTree.route,
        uiValue: summaryTree.isOccluded ? "" : summaryTree.value,
        uiId: uId,
        //uiId: summaryTree.isOccluded ? "" : generateStringHash(uId),
        uiClass: summaryTree.isOccluded ? "" : summaryTree.uiClass,
        uiType: summaryTree.isOccluded ? UX_UNKOWN : effectiveType,
        isSensitive: summaryTree.isOccluded,
      );
    } else {}

    print("messagex:" + trackData.toString());
    FlutterUxcam.appendGestureContent(position, trackData!);
  }
}
