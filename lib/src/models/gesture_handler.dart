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
        );
        addTreeIfInsideBounds(parent, node);
      }
      if (type == UX_TEXT || type == UX_IMAGE) {
        final subTree = _inspectNonInteractiveChild(element);
        if (subTree != null) {
          addTreeIfInsideBounds(node, subTree);
        }
        return;
      }
      if (type == UX_BUTTON) {
        final subTree = _inspectButtonChild(element);
        if (subTree != null) {
          addTreeIfInsideBounds(node, subTree);
        }
        //return;
      }
      if (type == UX_FIELD) {
        final subTree = _inspectTextFieldChild(element);
        if (subTree != null) {
          addTreeIfInsideBounds(node, subTree);
        }
        return;
      }
      if (type == UX_COMPOUND) {
        final subTree = _inspectInteractiveChild(element);
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

      if (element.widget is Icon) {
        final iconWidget = element.widget as Icon;
        String iconDataString = iconWidget.semanticLabel ?? "";
        if (iconWidget.icon != null) {
          iconDataString =
              "${iconWidget.icon!.fontFamily}-${iconWidget.icon!.codePoint.toRadixString(16)}";
        }
        if (element.getEffectiveBounds().contains(position)) {
          label = iconDataString;
        }
      }

      if (element.widget is Text && renderObject is RenderParagraph) {
        final textSpan = renderObject.text;
        if (textSpan is TextSpan) {
          final value = extractTextFromSpan(textSpan);
          if (label.isEmpty) {
            label = value;
          } else {
            if (element.getEffectiveBounds().contains(position)) {
              label = value;
            }
          }
        }
      }
      element.visitChildElements((element) => _extractTextFromButton(element));
    }

    _extractTextFromButton(element);
    if (label.isNotEmpty) {
      //there are cases where interactive elements like inkwell and gesturedetector do not have a child.
      subTree = SummaryTree(
        ModalRoute.of(element)?.settings.name ?? "",
        element.widget.runtimeType.toString(),
        UX_BUTTON,
        value: label,
        bound: element.getEffectiveBounds(),
      );
    }

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
    if (element.widget is RichText) {
      RichText widget = element.widget as RichText;
      if (widget.text is TextSpan) {
        subTree = SummaryTree(
          ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(),
          UX_TEXT,
          value: extractTextFromSpan(widget.text as TextSpan),
          bound: element.getEffectiveBounds(),
        );
      }
    }
    if (element.widget is Image) {
      String imageDataString = (element.widget as Image).image.toString();

      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
          value: imageDataString,
          bound: element.getEffectiveBounds(),
          custom: {
            "content_desc: ": imageDataString,
          });
    }
    if (element.widget is DecoratedBox) {
      subTree = SummaryTree(ModalRoute.of(element)?.settings.name ?? "",
          element.widget.runtimeType.toString(), UX_IMAGE,
          value: _extractImageStringRepresentation(element),
          bound: element.getEffectiveBounds(),
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
          custom: {
            "content_desc: ": iconDataString,
          });
    }
    return subTree;
  }

  String _extractImageStringRepresentation(Element element) {
    String imageDataString = "";
    if ((element.widget as DecoratedBox).decoration is BoxDecoration) {
      final decoration =
          (element.widget as DecoratedBox).decoration as BoxDecoration;
      final _image = decoration.image;
      if (_image != null) {
        imageDataString = _image.image.toString();
      }
      final _shape = decoration.shape;
      if (_image != null) {
        imageDataString = _image.image.toString();
      }
    } else {
      if ((element.widget as DecoratedBox).decoration is ShapeDecoration) {
        final decoration =
            (element.widget as DecoratedBox).decoration as ShapeDecoration;
        final _shape = decoration.shape;
        imageDataString = _shape.toString();
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
      // If not inside, check a small area around the position (10 points in each direction)
      if (!isInside) {
        const double delta = 10.0;
        final offsets = [
          Offset(position.dx + delta, position.dy),
          Offset(position.dx - delta, position.dy),
          Offset(position.dx, position.dy + delta),
          Offset(position.dx, position.dy - delta),
          Offset(position.dx + delta, position.dy + delta),
          Offset(position.dx - delta, position.dy - delta),
          Offset(position.dx + delta, position.dy - delta),
          Offset(position.dx - delta, position.dy + delta),
        ];
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
    SummaryTree? summaryTree = rootTree;
    String route = summaryTree!.route;
    if (route == "/") {
      route = "root";
    }
    uId += summaryTree.uiClass + "_";

    do {
      try {
        final subTree = summaryTree!.subTrees.last;
        uId += subTree.uiClass + "_";
        summaryTree = subTree;
      } on StateError {
        break;
      }
    } while (summaryTree.subTrees.isNotEmpty);

    if (summaryTree!.subTrees.isEmpty) {
      uId += formatValueToPseudoId(summaryTree.value);
      uId = summaryTree.route + "_" + uId;
      trackData = TrackData(
        summaryTree.bound,
        summaryTree.route,
        uiValue: summaryTree.value,
        uiId: uId,
        //uiId: generateStringHash(uId),
        uiClass: summaryTree.uiClass,
        uiType: summaryTree.type,
      );
    } else {}

    print("messagex:" + trackData.toString());
    FlutterUxcam.appendGestureContent(position, trackData!);
  }
}
