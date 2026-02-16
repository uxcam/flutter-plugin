import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Walks the Flutter render tree and injects a DOM snapshot
/// that the UXCam Web SDK captures via MutationObserver.
class FlutterWebRegistry {
  FlutterWebRegistry._();

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  Timer? _debounce;
  bool _isListening = false;
  web.HTMLElement? _container;

  void start() {
    if (_isListening) return;
    _isListening = true;

    // Poll until semantics owner is available, then attach listener
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      for (final renderView in RendererBinding.instance.renderViews) {
        final owner = renderView.owner?.semanticsOwner;
        if (owner == null) continue;

        owner.addListener(_onSemanticsChanged);
        timer.cancel();

        // Do initial scan
        _scheduleCollect();
        return;
      }
    });
  }

  void _onSemanticsChanged() {
    _scheduleCollect();
  }

  void _scheduleCollect() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _collectAndPush);
  }

  void _collectAndPush() {
    // Walk render tree, collect text snapshots
    final snapshots = <_TextSnapshot>[];
    final boxSnapshots = <_BoxSnapshot>[];
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement != null) {
      _walkRenderTree(rootElement, snapshots, boxSnapshots);
    }

    // Build DOM and inject
    _injectDom(snapshots, boxSnapshots);
  }

  /// Walk element tree, find RenderParagraph nodes, extract text info
  void _walkRenderTree(
    Element element,
    List<_TextSnapshot> textOut,
    List<_BoxSnapshot> boxOut,
  ) {
    final ro = element.renderObject;

    if (ro is RenderParagraph && ro.hasSize) {
      final text = ro.text.toPlainText();
      if (text.trim().isNotEmpty) {
        final transform = ro.getTransformTo(null);
        final translation = transform.getTranslation();
        final rect = ro.paintBounds.shift(
          Offset(translation.x, translation.y),
        );

        double? fontSize;
        Color? color;
        FontWeight? fontWeight;
        final span = ro.text;
        if (span is TextSpan && span.style != null) {
          fontSize = span.style!.fontSize;
          color = span.style!.color;
          fontWeight = span.style!.fontWeight;
        }

        if (fontSize == null && ro.size.height > 0) {
          final lineCount =
              ro.computeMaxIntrinsicHeight(double.infinity) / ro.size.height;
          if (lineCount <= 1.2) {
            fontSize = ro.size.height * 0.75;
          }
        }

        textOut.add(_TextSnapshot(
          text: text,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          fontSize: fontSize ?? 14.0,
          color: color,
          fontWeight: fontWeight,
        ));
      }
    }

    if (ro is RenderDecoratedBox && ro.hasSize) {
      final decoration = ro.decoration;
      if (decoration is BoxDecoration) {
        // Only capture if there's something visible (color or border)
        if (decoration.color != null || decoration.border != null) {
          final transform = ro.getTransformTo(null);
          final translation = transform.getTranslation();
          final rect = ro.paintBounds.shift(
            Offset(translation.x, translation.y),
          );

          boxOut.add(_BoxSnapshot(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            color: decoration.color,
            borderRadius: decoration.borderRadius,
            border: decoration.border,
          ));
        }
      }
    }

    element.visitChildElements((child) {
      _walkRenderTree(child, textOut, boxOut);
    });
  }


  /// Inject text snapshots as DOM elements
void _injectDom(List<_TextSnapshot> textSnapshots, List<_BoxSnapshot> boxSnapshots) {
  _container?.remove();

  final container = web.document.createElement('div') as web.HTMLElement;
  container.id = 'uxcam-render-snapshot';
  container.style.setProperty('position', 'absolute');
  container.style.setProperty('top', '0');
  container.style.setProperty('left', '0');
  container.style.setProperty('width', '100%');
  container.style.setProperty('height', '100%');
  container.style.setProperty('pointer-events', 'none');
  container.style.setProperty('overflow', 'hidden');
  container.style.setProperty('z-index', '-1');

  // Inject boxes first (behind text)
  for (final box in boxSnapshots) {
    final el = web.document.createElement('div') as web.HTMLElement;
    el.style.setProperty('position', 'absolute');
    el.style.setProperty('left', '${box.left.toStringAsFixed(1)}px');
    el.style.setProperty('top', '${box.top.toStringAsFixed(1)}px');
    el.style.setProperty('width', '${box.width.toStringAsFixed(1)}px');
    el.style.setProperty('height', '${box.height.toStringAsFixed(1)}px');

    if (box.color != null) {
      final c = box.color!;
      el.style.setProperty('background-color',
          'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
    }

    if (box.borderRadius != null) {
      final br = box.borderRadius!.resolve(TextDirection.ltr);
      el.style.setProperty('border-radius',
          '${br.topLeft.x.toStringAsFixed(1)}px '
          '${br.topRight.x.toStringAsFixed(1)}px '
          '${br.bottomRight.x.toStringAsFixed(1)}px '
          '${br.bottomLeft.x.toStringAsFixed(1)}px');
    }

    if (box.border != null && box.border is Border) {
      final b = box.border! as Border;
      _applyBorderSide(el, 'top', b.top);
      _applyBorderSide(el, 'right', b.right);
      _applyBorderSide(el, 'bottom', b.bottom);
      _applyBorderSide(el, 'left', b.left);
    }

    container.appendChild(el);
  }

  // Inject text on top
  for (final snap in textSnapshots) {
    final el = web.document.createElement('span') as web.HTMLElement;
    el.textContent = snap.text;
    el.style.setProperty('position', 'absolute');
    el.style.setProperty('left', '${snap.left.toStringAsFixed(1)}px');
    el.style.setProperty('top', '${snap.top.toStringAsFixed(1)}px');
    el.style.setProperty('width', '${snap.width.toStringAsFixed(1)}px');
    el.style.setProperty('height', '${snap.height.toStringAsFixed(1)}px');
    el.style.setProperty('font-size', '${snap.fontSize.toStringAsFixed(1)}px');
    el.style.setProperty('line-height', '${snap.height.toStringAsFixed(1)}px');
    el.style.setProperty('overflow', 'hidden');
    el.style.setProperty('white-space', 'nowrap');

    if (snap.color != null) {
      final c = snap.color!;
      el.style.setProperty('color',
          'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
    }

    if (snap.fontWeight != null && snap.fontWeight != FontWeight.normal) {
      el.style.setProperty('font-weight', '${snap.fontWeight!.value}');
    }

    container.appendChild(el);
  }

  web.document.body?.appendChild(container);
  _container = container;
}

  void _applyBorderSide(web.HTMLElement el, String side, BorderSide bs) {
    if (bs.width > 0 && bs.style != BorderStyle.none) {
      final c = bs.color;
      el.style.setProperty('border-$side',
          '${bs.width.toStringAsFixed(1)}px solid '
          'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
    }
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _container?.remove();
    _container = null;
    _isListening = false;
  }
}

class _TextSnapshot {
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  _TextSnapshot({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.fontSize,
    this.color,
    this.fontWeight,
  });
}

class _BoxSnapshot {
  final double left;
  final double top;
  final double width;
  final double height;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final BoxBorder? border;

  _BoxSnapshot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.color,
    this.borderRadius,
    this.border,
  });
}


@JS('eval')
external void _evalJs(JSString code);
