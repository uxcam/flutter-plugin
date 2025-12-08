import 'dart:math';

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
    // Collect candidates and upgrade to semantic ancestors
    // Many widgets (like Text) don't have RenderObjects - they delegate to
    // internal widgets (like RichText). We walk UP to find the semantic widget.
    final candidates = <_CandidateInfo>[];
    final seenElements = <Element>{};
    final matches = _registry.getMatchingElements(hitTargetHashes);

    for (final entry in matches) {
      final hash = entry.key;
      final element = entry.value;

      if (!element.mounted) continue;

      final cachedInfo = _registry.getCachedInfo(hash);
      final type = cachedInfo?.uxType ??
          UXCamWidgetClassifier.classifyElement(element);

      if (type == UX_UNKNOWN) continue;

      final bounds = _getElementBounds(element);
      final containsPosition =
          bounds.contains(position) || _containsWithTolerance(bounds, position, 10.0);

      if (containsPosition) {
        // Try to find a better same-type ancestor (e.g., Text instead of RichText)
        final semanticElement = _findSemanticAncestor(element, type) ?? element;

        // Avoid duplicates when multiple hit targets upgrade to same ancestor
        if (seenElements.contains(semanticElement)) continue;
        seenElements.add(semanticElement);

        candidates.add(_CandidateInfo(
          hash: hash,
          element: semanticElement,
          type: type,
        ));
      }
    }

    if (candidates.isEmpty) return null;

    // Select best (prefer interactive over non-interactive)
    _CandidateInfo? best;
    for (final candidate in candidates) {
      if (best == null) {
        best = candidate;
      } else {
        final bestIsInteractive = _isInteractiveType(best.type);
        final candidateIsInteractive = _isInteractiveType(candidate.type);

        if (candidateIsInteractive && !bestIsInteractive) {
          best = candidate;
        }
        // If both have same interactivity, keep the first one found
      }
    }

    if (best == null) return null;

    return _ExtractionResult(
      element: best.element,
      hash: best.hash,
      type: best.type,
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

  bool _containsWithTolerance(Rect bounds, Offset position, double radius) {
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

    final value = _extractValue(element, type);
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

  String _extractValue(Element element, int type) {
    final widget = element.widget;

    switch (type) {
      case UX_TEXT:
        return _extractTextValue(widget);
      case UX_IMAGE:
        return _extractImageValue(element, widget);
      case UX_FIELD:
        return _extractFieldValue(widget);
      case UX_BUTTON:
        return _extractButtonLabel(element);
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
    return '';
  }

  String _extractButtonLabel(Element element) {
    String label = '';

    void visitChildren(Element child) {
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

class _CandidateInfo {
  final int hash;
  final Element element;
  final int type;

  _CandidateInfo({
    required this.hash,
    required this.element,
    required this.type,
  });
}
