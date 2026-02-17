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
  Timer? _rescanTimer;     
  bool _isListening = false;
  int _lastSnapshotHash = 0;
  web.HTMLElement? _container;
  final Set<ScrollPosition> _trackedPositions = {};

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
        _rescanTimer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => _scheduleCollect(),
        );
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

    final hash = Object.hashAll([
      ...snapshots.map((s) => Object.hash(s.text, s.left.round(), s.top.round())),
      ...boxSnapshots.map((b) => Object.hash(b.imageUrl, b.left.round(), b.top.round())),
    ]);
    if (hash == _lastSnapshotHash) return;
    _lastSnapshotHash = hash;

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

    // Skip entire subtree if offstage or hidden
    if (ro is RenderOffstage && ro.offstage) return;
    if (ro is RenderAnimatedOpacity && ro.opacity.value == 0.0) return;
    if (ro is RenderOpacity && ro.opacity == 0.0) return;

    // Skip entire subtree if this element's render object is a RepaintBoundary
    if (ro != null && ro.isRepaintBoundary && ro.layer != null) {
      if (!(ro.layer?.attached ?? false)) return;
    }

    if (ro is RenderParagraph && ro.hasSize) {
      final text = ro.text.toPlainText();
      if (text.trim().isNotEmpty) {
        final transform = ro.getTransformTo(null);
        final translation = transform.getTranslation();
        final rect = ro.paintBounds.shift(
          Offset(translation.x, translation.y),
        );
        if (!_isInViewport(rect)) return;

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
          if (!_isInViewport(rect)) return;

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

    // Capture Card/Material backgrounds (RenderPhysicalShape)
    if (ro is RenderPhysicalShape && ro.hasSize) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
      if (_isInViewport(rect)) {
        // Extract border radius from the clipper if available
        BorderRadiusGeometry? borderRadius;
        final clipper = ro.clipper;
        if (clipper is ShapeBorderClipper) {
          final shape = clipper.shape;
          if (shape is RoundedRectangleBorder) {
            borderRadius = shape.borderRadius;
          }
        }

        boxOut.add(_BoxSnapshot(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          color: ro.color,
          borderRadius: borderRadius,
        ));
      }
    }

    // Capture Material/Scaffold/AppBar backgrounds (RenderPhysicalModel)
    if (ro is RenderPhysicalModel && ro.hasSize) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
      if (_isInViewport(rect)) {
        boxOut.add(_BoxSnapshot(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          color: ro.color,
          borderRadius: ro.borderRadius,
        ));
      }
    }

    if (ro is RenderImage && ro.hasSize) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );

      if (!_isInViewport(rect)) return;

      final widget = element.widget;
      String? url;

      // Walk up to find the Image widget that owns this RenderImage
      if (widget is Image) {
        url = _extractImageUrl(widget);
      } else {
        // Sometimes RenderImage is nested under RawImage, walk up
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is Image) {
            url = _extractImageUrl(ancestor.widget as Image);
            return false; // stop
          }
          return true; // keep looking
        });
      }

      if (url != null) {
        boxOut.add(_BoxSnapshot(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          imageUrl: url,
        ));
      }
    }


    // Detect active scroll positions and listen for changes
    if (ro is RenderAbstractViewport && ro is RenderBox && (ro as RenderBox).hasSize) {
      final widget = element.widget;
      if (widget is Scrollable) {
        final position = widget.controller?.position;
        if (position != null && !_trackedPositions.contains(position)) {
          _trackedPositions.add(position);
          position.addListener(_onScrollChanged);
        }
      }
    }

    element.visitChildElements((child) {
      _walkRenderTree(child, textOut, boxOut);
    });
  }

  void _onScrollChanged() {
    _scheduleCollect();
  }

  bool _isInViewport(Rect rect) {
    final viewWidth = web.window.innerWidth.toDouble();
    final viewHeight = web.window.innerHeight.toDouble();
    return rect.right > 0 && rect.left < viewWidth &&
          rect.bottom > 0 && rect.top < viewHeight;
  }

  String? _extractImageUrl(Image widget) {
    final provider = widget.image;
    if (provider is NetworkImage) return provider.url;
    if (provider is AssetImage) return provider.assetName;
    if (provider is ExactAssetImage) return provider.assetName;

    // Fallback: parse from toString()
    final str = provider.toString();
    final regex = RegExp(r'"([^"]+)"');
    final match = regex.firstMatch(str);
    if (match != null && match.group(1) != 'null') {
      return match.group(1);
    }
    return null;
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

    if (box.imageUrl != null) {
      final img = web.document.createElement('img') as web.HTMLImageElement;
      img.src = box.imageUrl!;
      img.style.setProperty('width', '100%');
      img.style.setProperty('height', '100%');
      img.style.setProperty('object-fit', 'cover');
      img.style.setProperty('pointer-events', 'none');
      el.appendChild(img);
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
    _rescanTimer?.cancel();
    _rescanTimer = null;
    _lastSnapshotHash = 0; 
    for (final pos in _trackedPositions) {
      pos.removeListener(_onScrollChanged);
    }
    _trackedPositions.clear();
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
  final String? imageUrl;

  _BoxSnapshot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.color,
    this.borderRadius,
    this.border,
    this.imageUrl,
  });
}
