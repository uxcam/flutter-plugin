import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';

import 'uxcam_element_registry.dart';
import 'uxcam_route_tracker.dart';
import 'uxcam_widget_classifier.dart';

/// Widget information extractor for smart events.
class UXCamWidgetExtractor {
  // Use eager singleton to prevent resurrection issues
  static final UXCamWidgetExtractor _instance = UXCamWidgetExtractor._internal();
  factory UXCamWidgetExtractor() => _instance;
  UXCamWidgetExtractor._internal();

  late UXCamElementRegistry _registry;
  late UXCamRouteTracker _routeTracker;
  bool _isInitialized = false;

  void initialize({
    required UXCamElementRegistry registry,
    required UXCamRouteTracker routeTracker,
  }) {
    if (_isInitialized) return;
    _isInitialized = true;

    _registry = registry;
    _routeTracker = routeTracker;
  }

  void dispose() {
    _isInitialized = false;
    // Don't null out _instance - eager singleton prevents resurrection
  }

  void extractAndSend(Offset position, Set<int> hitTargetHashes) {
    if (!_isInitialized) return;

    _registry.ensureFreshForTap(hitTargetHashes);

    final extractionResult = _findBestElement(position, hitTargetHashes);
    if (extractionResult == null) return;

    final trackData = _buildTrackData(position, extractionResult);
    if (trackData != null) {
      FlutterUxcam.appendGestureContent(position, trackData);
    }
  }

  _ExtractionResult? _findBestElement(
      Offset position, Set<int> hitTargetHashes) {
    final matches = _registry.getMatchingElements(hitTargetHashes);

    // Find first valid candidate (hit order = specificity order)
    Element? targetElement;
    int? targetHash;
    int? targetType;

    for (final entry in matches) {
      final element = entry.value;
      if (!element.mounted) continue;

      final cachedInfo = _registry.getCachedInfo(entry.key);
      final type =
          cachedInfo?.uxType ?? UXCamWidgetClassifier.classifyElement(element);
      if (type == UX_UNKNOWN) continue;

      final bounds = _getElementBounds(element);
      if (!bounds.contains(position) &&
          !_containsWithTolerance(bounds, position, 10.0)) {
        continue;
      }

      targetElement = element;
      targetHash = entry.key;
      targetType = type;
      break; // First valid = most specific
    }

    if (targetElement == null) return null;

    // Upgrade to semantic ancestor (RichText → Text)
    final semanticElement =
        _findSemanticAncestor(targetElement, targetType!) ?? targetElement;

    // If non-interactive, check if it's a label for an interactive parent
    if (!_isInteractiveType(targetType)) {
      final labelOwner = _findLabelOwner(semanticElement);
      if (labelOwner != null) {
        return _ExtractionResult(
          element: labelOwner,
          hash: identityHashCode(labelOwner.renderObject),
          type: UXCamWidgetClassifier.classifyElement(labelOwner),
        );
      }
    }

    return _ExtractionResult(
      element: semanticElement,
      hash: targetHash!,
      type: targetType,
    );
  }

  /// Walk up the element tree to find the highest same-type ancestor.
  /// This upgrades implementation widgets to their semantic parents:
  /// - RichText → Text (Text has no RenderObject, delegates to RichText)
  /// - GestureDetector → InkWell → ElevatedButton (returns ElevatedButton)
  Element? _findSemanticAncestor(Element element, int type) {
    Element? highest;
    element.visitAncestorElements((ancestor) {
      final ancestorType = UXCamWidgetClassifier.classifyElement(ancestor);
      if (ancestorType == type) {
        highest = ancestor; // Keep going to find the highest
      }
      return true; // Continue searching all the way up
    });
    return highest;
  }

  bool _isInteractiveType(int type) {
    return type == UX_BUTTON || type == UX_FIELD || type == UX_COMPOUND;
  }

  /// Returns interactive ancestor if element is its sole content widget.
  /// e.g., Text inside ElevatedButton → returns ElevatedButton
  /// But Text inside Row[Icon, Text] inside Button → returns null (not sole content)
  Element? _findLabelOwner(Element element) {
    Element? result;

    element.visitAncestorElements((ancestor) {
      final type = UXCamWidgetClassifier.classifyElement(ancestor);
      if (_isInteractiveType(type)) {
        if (_isSoleContent(ancestor, element)) {
          result = ancestor;
        }
        return false; // Stop at first interactive ancestor
      }
      return true;
    });

    return result;
  }

  /// Check if child is the only content widget inside parent
  bool _isSoleContent(Element parent, Element target) {
    int contentCount = 0;
    bool foundTarget = false;

    void visit(Element el) {
      final type = UXCamWidgetClassifier.classifyElement(el);

      if (type == UX_TEXT || type == UX_IMAGE) {
        contentCount++;
        if (identical(el, target)) foundTarget = true;
        return; // Don't recurse into content widgets
      }

      if (_isInteractiveType(type)) return; // Don't recurse into nested interactive

      el.visitChildElements(visit);
    }

    parent.visitChildElements(visit);
    return foundTarget && contentCount == 1;
  }

  bool _containsWithTolerance(Rect bounds, Offset position, double radius) {
    // Check the position itself first
    if (bounds.contains(position)) {
      return true;
    }

    // Then check points around the position within the tolerance radius
    const int numPoints = 8;
    final offsets = List.generate(numPoints, (i) {
      final angle = (2 * pi * i) / numPoints;
      return Offset(
        position.dx + radius * cos(angle),
        position.dy + radius * sin(angle),
      );
    });

    for (final offset in offsets) {
      if (bounds.contains(offset)) {
        return true;
      }
    }
    return false;
  }

  Rect _getElementBounds(Element element) {
    final renderObject = element.renderObject;
    if (renderObject is RenderBox && renderObject.hasSize) {
      final translation = renderObject.getTransformTo(null).getTranslation();
      final offset = Offset(translation.x, translation.y);
      return renderObject.paintBounds.shift(offset);
    }
    return Rect.zero;
  }

  TrackData? _buildTrackData(Offset position, _ExtractionResult result) {
    final element = result.element;
    final type = result.type;

    final route = _routeTracker.getRouteForElement(element);
    final bounds = _getElementBounds(element);
    if (bounds == Rect.zero) return null;

    final widgetType =
        UXCamWidgetClassifier.getDisplayName(element.widget.runtimeType);

    final isOccluded =
        element.findAncestorWidgetOfExactType<OccludeWrapper>() != null;

    final value = _extractValue(element, type, position);
    final uiId = _generateUiId(route, widgetType, value);

    return TrackData(
      bounds,
      route,
      uiValue: isOccluded ? '' : value,
      uiId: isOccluded ? '' : uiId,
      uiClass: isOccluded ? '' : widgetType,
      uiType: isOccluded ? UX_UNKNOWN : type,
      isSensitive: isOccluded,
    );
  }

  String _extractValue(Element element, int type, Offset position) {
    final widget = element.widget;

    switch (type) {
      case UX_TEXT:
        return _extractTextValue(widget);
      case UX_IMAGE:
        return _extractImageValue(element, widget);
      case UX_FIELD:
        return _extractFieldValue(widget);
      case UX_BUTTON:
        return _extractButtonLabel(element, position);
      default:
        return '';
    }
  }

  String _extractTextValue(Widget widget) {
    if (widget is Text) return widget.data ?? '';
    if (widget is RichText) {
      if (widget.text is TextSpan) {
        return _extractTextFromSpan(widget.text as TextSpan);
      }
    }
    if (widget is SelectableText) return widget.data ?? '';
    return '';
  }

  String _extractTextFromSpan(TextSpan span) {
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

  String _extractImageValue(Element element, Widget widget) {
    if (widget is Image) {
      return _extractImagePath(widget.image.toString()) ?? '';
    }
    if (widget is Icon) {
      if (widget.semanticLabel != null) return widget.semanticLabel!;
      if (widget.icon != null) {
        return '${widget.icon!.fontFamily}-${widget.icon!.codePoint.toRadixString(16)}';
      }
    }
    if (widget is DecoratedBox) {
      return _extractDecoratedBoxImage(widget);
    }
    return '';
  }

  String? _extractImagePath(String input) {
    final regex = RegExp(r'"([^"]+)"');
    final match = regex.firstMatch(input);
    return match?.group(1) != 'null' ? match?.group(1) : null;
  }

  String _extractDecoratedBoxImage(DecoratedBox widget) {
    if (widget.decoration is BoxDecoration) {
      final decoration = widget.decoration as BoxDecoration;
      final image = decoration.image;
      if (image != null) {
        return _extractImagePath(image.image.toString()) ?? '';
      }
    }
    return '';
  }

  String _extractFieldValue(Widget widget) {
    if (widget is TextField) {
      return widget.decoration?.hintText ?? widget.decoration?.labelText ?? '';
    }
    // Note: TextFormField doesn't expose decoration directly.
    // The decoration is passed to the internal TextField builder.
    // We handle this by extracting text from child TextField in _extractValue.
    if (widget is CupertinoTextField) {
      return widget.placeholder ?? '';
    }
    if (widget is CupertinoSearchTextField) {
      return widget.placeholder ?? 'Search';
    }
    return '';
  }

  String _extractButtonLabel(Element element, Offset position) {
    String label = '';

    void visitChildren(Element child) {
      if (label.isNotEmpty) return;

      // Only extract from children at tap position
      final bounds = _getElementBounds(child);
      if (bounds != Rect.zero && !bounds.contains(position)) {
        // Still recurse - the actual text widget might be deeper
        child.visitChildElements(visitChildren);
        return;
      }

      final widget = child.widget;
      if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
        label = widget.data!;
        return;
      }
      if (widget is RichText && widget.text is TextSpan) {
        final text = _extractTextFromSpan(widget.text as TextSpan);
        if (text.isNotEmpty) {
          label = text;
          return;
        }
      }
      if (widget is Icon && widget.semanticLabel != null) {
        label = widget.semanticLabel!;
        return;
      }
      if (label.isEmpty) {
        child.visitChildElements(visitChildren);
      }
    }

    element.visitChildElements(visitChildren);
    return label;
  }

  String _generateUiId(String route, String widgetType, String value) {
    final input = '$route#$widgetType#${_formatValueToPseudoId(value)}';
    return '$route:${_generateStringHash(input)}';
  }

  String _formatValueToPseudoId(String value) =>
      value.replaceAll(' ', '').toLowerCase();

  String _generateStringHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    }
    return hash.toUnsigned(32).toRadixString(16);
  }

  bool get isInitialized => _isInitialized;
}

class _ExtractionResult {
  final Element element;
  final int hash;
  final int type;

  _ExtractionResult({
    required this.element,
    required this.hash,
    required this.type,
  });
}

