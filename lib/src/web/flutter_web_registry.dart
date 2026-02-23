import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/web/snapshot.dart';
import 'package:web/web.dart' as web;

@JS('console.log')
external void _consoleLog(JSString message);

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

  void start() {
      if (_isListening) return;
      _isListening = true;

      _rescanTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _collectAndPush(),
      );
    }

  void _collectAndPush() {
      try {
        final snapshots = <Snapshot>[];
        final rootElement = WidgetsBinding.instance.rootElement;
        if (rootElement != null) {
          _walkRenderTree(rootElement, snapshots);
        }

        final hash = Object.hashAll([
          ...snapshots.map((s) => Object.hash(s.text, (s.left / 10).round(), (s.top / 10).round(),s.color?.value ?? 0,
            s.fontColor?.value ?? 0,)),
        ]);
        if (hash == _lastSnapshotHash) return;
        _lastSnapshotHash = hash;

        _injectDom(snapshots);
      } catch (e, st) {
        _consoleLog('[UXCam-Flutter] ERROR: $e\n$st'.toJS);
      }
    }


  /// Walk element tree, find RenderParagraph nodes, extract text info
  void _walkRenderTree(
    Element element,
    List<Snapshot> out, {
    Rect? clipBounds,
    }
  ) {
    final ro = element.renderObject;

    // Skip entire subtree if offstage or hidden
    if (ro is RenderOffstage && ro.offstage) return;
    if (ro is RenderAnimatedOpacity && ro.opacity.value == 0.0) return;
    if (ro is RenderOpacity && ro.opacity == 0.0) return;

    // Accumulate clip bounds from clip render objects and scroll viewports.
    // Children will be checked against these bounds + the browser viewport.
    Rect? effectiveClip = clipBounds;

    if (ro is RenderClipPath && ro.hasSize) {
      final clipper = ro.clipper;
      Rect localClip;
      if (clipper != null) {
        localClip = clipper.getClip(ro.size).getBounds();
      } else {
        localClip = Offset.zero & ro.size;
      }
      if (localClip.width < 1.0 || localClip.height < 1.0) return;
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip = localClip.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return;
    }

    if (ro is RenderClipRect && ro.hasSize) {
      final clipper = ro.clipper;
      final localClip = clipper?.getClip(ro.size) ?? (Offset.zero & ro.size);
      if (localClip.width < 1.0 || localClip.height < 1.0) return;
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip = localClip.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return;
    }

    if (ro is RenderClipRRect && ro.hasSize) {
      final clipper = ro.clipper;
      Rect localClip;
      if (clipper != null) {
        localClip = clipper.getClip(ro.size).outerRect;
      } else {
        localClip = Offset.zero & ro.size;
      }
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip = localClip.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return;
    }

    // Clip to scrollable viewport bounds (ListView, GridView, etc.)
    // RenderViewport clips content in its paint() method via clipBehavior,
    // not through a separate RenderClipRect — so we handle it explicitly.
    if (ro is RenderViewportBase && ro.hasSize && ro.clipBehavior != Clip.none) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip = ro.paintBounds.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return;
    }

    // Skip entire subtree if this element's render object is a RepaintBoundary
    if (ro != null && ro.isRepaintBoundary) {
      // ignore: invalid_use_of_protected_member
      if (ro.layer != null && !(ro.layer?.attached ?? false)) return;
    }

    if (ro is RenderParagraph && ro.hasSize) {
      final text = ro.text.toPlainText();
      if (text.trim().isNotEmpty) {
        final transform = ro.getTransformTo(null);
        final translation = transform.getTranslation();
        Rect rect = ro.paintBounds.shift(
          Offset(translation.x, translation.y),
        );
        final visRect = _visibleRect(rect, clipBounds: effectiveClip);
        if (visRect == null) return;
        rect = visRect;

        double? fontSize;
        Color? color;
        FontWeight? fontWeight;
        final span = ro.text;
        if (span is TextSpan && span.style != null) {
          fontSize = span.style!.fontSize;
          color = span.style!.color;
          fontWeight = span.style!.fontWeight;
        }

        if (color == null) {
          try {
            final defaultStyle = DefaultTextStyle.of(element);
            color = defaultStyle.style.color;
          } catch (_) {}
        }

        if (color == null) {
          try {
            element.visitAncestorElements((ancestor) {
              final w = ancestor.widget;
              if (w is DefaultTextStyle && w.style.color != null) {
                color = w.style.color;
                return false;
              }
              return true;
            });
          } catch (_) {}
        }

        if (color == null) {
          try {
            final resolved = ro.text.style;
            color = resolved?.color;
          } catch (_) {}
        }

        if (fontSize == null && ro.size.height > 0) {
          final lineCount =
              ro.computeMaxIntrinsicHeight(double.infinity) / ro.size.height;
          if (lineCount <= 1.2) {
            fontSize = ro.size.height * 0.75;
          }
        }

        out.add(Snapshot(
          type: SnapType.text,
          order: out.length,
          text: text,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          fontSize: fontSize ?? 14.0,
          fontColor: color,
          fontWeight: fontWeight,
        ));
      }
    }

    // Capture editable text (TextField, TextFormField)
    if (ro is RenderEditable && ro.hasSize) {
      final text = ro.text?.toPlainText() ?? '';
      if (text.trim().isNotEmpty) {
        final transform = ro.getTransformTo(null);
        final translation = transform.getTranslation();
        Rect rect = ro.paintBounds.shift(
          Offset(translation.x, translation.y),
        );
        final visRect = _visibleRect(rect, clipBounds: effectiveClip);
        if (visRect!=null) {
          rect = visRect;
          double? fontSize;
          Color? color;
          FontWeight? fontWeight;
          final span = ro.text;
          if (span is TextSpan && span.style != null) {
            fontSize = span.style!.fontSize;
            color = span.style!.color;
            fontWeight = span.style!.fontWeight;
          }

          out.add(Snapshot(
            type: SnapType.text,
            order: out.length,
            text: text,
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            fontSize: fontSize ?? 14.0,
            fontColor: color,
            fontWeight: fontWeight,
          ));
        }
      }
    }

        // Capture TextField/TextFormField borders (InputDecorator uses private _RenderDecoration)
    if (element.widget is InputDecorator && ro is RenderBox && ro.hasSize) {
      final inputDecorator = element.widget as InputDecorator;
      final decoration = inputDecorator.decoration;
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      Rect rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
      final visRect = _visibleRect(rect, clipBounds: effectiveClip);
      if (visRect!=null) {
        rect = visRect;
        // Determine the border to use based on state
        final isFocused = inputDecorator.isFocused;
        InputBorder? border = isFocused
            ? (decoration.focusedBorder ?? decoration.border)
            : (decoration.enabledBorder ?? decoration.border);
        border ??= const UnderlineInputBorder();

        final borderColor = border.borderSide.color;
        final borderWidth = border.borderSide.width;

        if (border is OutlineInputBorder) {
          out.add(Snapshot(
            type: SnapType.box,
            order: out.length,
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            borderRadius: border.borderRadius,
            border: Border.all(color: borderColor, width: borderWidth),
          ));
        } else {
          // UnderlineInputBorder — just a bottom border
          out.add(Snapshot(
            type: SnapType.box,
            order: out.length,
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            border: Border(
              bottom: BorderSide(color: borderColor, width: borderWidth),
            ),
          ));
        }
      }
    }


    if (ro is RenderDecoratedBox && ro.hasSize) {
      final decoration = ro.decoration;
      if (decoration is BoxDecoration) {
        // Only capture if there's something visible (color or border)
        if (decoration.color != null || decoration.border != null) {
          final transform = ro.getTransformTo(null);
          final translation = transform.getTranslation();
          Rect rect = ro.paintBounds.shift(
            Offset(translation.x, translation.y),
          );
          final visRect = _visibleRect(rect, clipBounds: effectiveClip);
          if (visRect == null) return;
          rect = visRect;

          out.add(Snapshot(
            type: SnapType.box,
            order: out.length,
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

    // Capture ColoredBox (Container(color:) uses private _RenderColoredBox)
    if (element.widget is ColoredBox && ro is RenderBox && ro.hasSize) {
      final coloredBox = element.widget as ColoredBox;
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      Rect rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
      final visRect = _visibleRect(rect, clipBounds: effectiveClip);
      if (visRect!=null) {
        rect = visRect;
        out.add(Snapshot(
          type: SnapType.box,
          order: out.length,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          color: coloredBox.color,
        ));
      }
    }

    // Capture Card/Material backgrounds (RenderPhysicalShape)
    if (ro is RenderPhysicalShape && ro.hasSize) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      Rect rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
      final visRect = _visibleRect(rect, clipBounds: effectiveClip);
      if (visRect!=null) {
        rect = visRect;
        // Extract border radius from the clipper if available
        BorderRadiusGeometry? borderRadius;
        final clipper = ro.clipper;
        if (clipper is ShapeBorderClipper) {
          final shape = clipper.shape;
          if (shape is RoundedRectangleBorder) {
            borderRadius = shape.borderRadius;
          }
        }

        out.add(Snapshot(
          type: SnapType.box,
          order: out.length,
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
      Rect rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
      final visRect = _visibleRect(rect, clipBounds: effectiveClip);
      if (visRect!=null) {
        rect = visRect;
        out.add(Snapshot(
          type: SnapType.box,
          order: out.length,
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
      Rect rect = ro.paintBounds.shift(
        Offset(translation.x, translation.y),
      );

      final visRect = _visibleRect(rect, clipBounds: effectiveClip);
      if (visRect == null) return;
      rect = visRect;
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
        out.add(Snapshot(
          type: SnapType.box,
          order: out.length,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          imageUrl: url,
        ));
      }
    }


    element.visitChildElements((child) {
      _walkRenderTree(child, out, clipBounds: effectiveClip);
    });
  }

  /// Returns the visible portion of [rect] after clipping to the browser
  /// viewport and any ancestor [clipBounds]. Returns null if completely
  /// outside the visible area.
  Rect? _visibleRect(Rect rect, {Rect? clipBounds}) {
    final viewWidth = web.window.innerWidth.toDouble();
    final viewHeight = web.window.innerHeight.toDouble();
    // Completely outside browser viewport
    if (rect.right <= 0 || rect.left >= viewWidth ||
        rect.bottom <= 0 || rect.top >= viewHeight) {
      return null;
    }
    // Completely outside ancestor clip bounds
    if (clipBounds != null) {
      if (rect.right <= clipBounds.left || rect.left >= clipBounds.right ||
          rect.bottom <= clipBounds.top || rect.top >= clipBounds.bottom) {
        return null;
      }
      // Clamp to clip bounds so the DOM element only covers the visible portion
      return Rect.fromLTRB(
        rect.left < clipBounds.left ? clipBounds.left : rect.left,
        rect.top < clipBounds.top ? clipBounds.top : rect.top,
        rect.right > clipBounds.right ? clipBounds.right : rect.right,
        rect.bottom > clipBounds.bottom ? clipBounds.bottom : rect.bottom,
      );
    }
    return rect;
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
  
void _injectDom(List<Snapshot> snapshots) {
    var container = _container;
    if (container == null) {
      container = web.document.createElement('div') as web.HTMLElement;
      container.id = 'uxcam-render-snapshot';
      container.style.setProperty('position', 'absolute');
      container.style.setProperty('top', '0');
      container.style.setProperty('left', '0');
      container.style.setProperty('width', '100%');
      container.style.setProperty('height', '100%');
      container.style.setProperty('pointer-events', 'none');
      container.style.setProperty('overflow', 'hidden');
      container.style.setProperty('z-index', '-1');
      web.document.body?.appendChild(container);
      _container = container;
    }

    // Build a map of existing elements keyed by data-key
    final existingByKey = <String, web.HTMLElement>{};
    final toRemove = <web.HTMLElement>[];
    for (var i = 0; i < container.children.length; i++) {
      final child = container.children.item(i)! as web.HTMLElement;
      final key = child.getAttribute('data-key') ?? '';
      if (key.isNotEmpty) {
        existingByKey[key] = child;
      } else {
        toRemove.add(child);
      }
    }

    final usedKeys = <String>{};
    final keyCounter = <String, int>{};

    for (final snap in snapshots) {
      // Generate a stable key based on content identity, not position
      final baseKey = _snapshotKey(snap); 
      final count = keyCounter[baseKey] ?? 0;   
      keyCounter[baseKey] = count + 1; 
      final key = '${baseKey}_$count';

      web.HTMLElement? el = existingByKey[key];
      final isNew = el == null;

      if (isNew) {
        el = web.document.createElement(
          snap.type == SnapType.text ? 'span' : 'div',
        ) as web.HTMLElement;
        el.setAttribute('data-key', key);
        container.appendChild(el);
      }

      usedKeys.add(key);

      // Update position and size (style-only, no childList mutations)
      el.style.setProperty('position', 'absolute');
      el.style.setProperty('left', '${snap.left.toStringAsFixed(1)}px');
      el.style.setProperty('top', '${snap.top.toStringAsFixed(1)}px');
      el.style.setProperty('width', '${snap.width.toStringAsFixed(1)}px');
      el.style.setProperty('height', '${snap.height.toStringAsFixed(1)}px');
      el.style.setProperty('z-index', '${snap.order}');

      if (snap.type == SnapType.box) {
        if ((el.textContent ?? '').isNotEmpty) {
          el.textContent = '';
        }

        if (snap.color != null) {
          final c = snap.color!;
          el.style.setProperty('background-color',
              'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
        } else {
          el.style.removeProperty('background-color');
        }

        if (snap.borderRadius != null) {
          final br = snap.borderRadius!.resolve(TextDirection.ltr);
          el.style.setProperty('border-radius',
              '${br.topLeft.x.toStringAsFixed(1)}px '
              '${br.topRight.x.toStringAsFixed(1)}px '
              '${br.bottomRight.x.toStringAsFixed(1)}px '
              '${br.bottomLeft.x.toStringAsFixed(1)}px');
        } else {
          el.style.removeProperty('border-radius');
        }

        if (snap.border != null && snap.border is Border) {
          final b = snap.border! as Border;
          _applyBorderSide(el, 'top', b.top);
          _applyBorderSide(el, 'right', b.right);
          _applyBorderSide(el, 'bottom', b.bottom);
          _applyBorderSide(el, 'left', b.left);
        } else {
          el.style.removeProperty('border-top');
          el.style.removeProperty('border-right');
          el.style.removeProperty('border-bottom');
          el.style.removeProperty('border-left');
        }

        if (snap.imageUrl != null) {
          var img = el.querySelector('img') as web.HTMLImageElement?;
          if (img == null) {
            img = web.document.createElement('img') as web.HTMLImageElement;
            img.style.setProperty('width', '100%');
            img.style.setProperty('height', '100%');
            img.style.setProperty('object-fit', 'cover');
            img.style.setProperty('pointer-events', 'none');
            el.appendChild(img);
          }
          if (img.getAttribute('src') != snap.imageUrl!) {
            img.src = snap.imageUrl!;
          }
        } else {
          final existingImg = el.querySelector('img');
          existingImg?.remove();
        }
      } else {
        // Text element
        if (el.textContent != snap.text) {
          el.textContent = snap.text;
        }
        el.style.setProperty('font-size', '${snap.fontSize.toStringAsFixed(1)}px');
        el.style.setProperty('overflow', 'hidden');

        final isMultiLine = snap.height > snap.fontSize * 1.8;
        if (isMultiLine) {
          el.style.setProperty('white-space', 'normal');
          el.style.setProperty('line-height',
              '${(snap.fontSize * 1.4).toStringAsFixed(1)}px');
        } else {
          el.style.setProperty('white-space', 'nowrap');
          el.style.setProperty('line-height',
              '${snap.height.toStringAsFixed(1)}px');
        }

        if (snap.fontColor != null) {
          final c = snap.fontColor!;
          el.style.setProperty('color',
              'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
        } else {
          el.style.removeProperty('color');
        }

        if (snap.fontWeight != null && snap.fontWeight != FontWeight.normal) {
          el.style.setProperty('font-weight', '${snap.fontWeight!.value}');
        } else {
          el.style.removeProperty('font-weight');
        }
      }
    }

    // Remove elements whose keys are no longer in the snapshot list
    for (final entry in existingByKey.entries) {
      if (!usedKeys.contains(entry.key)) {
        entry.value.remove();
      }
    }
    for (final el in toRemove) {
      el.remove();
    }
  }

  /// Generate a stable identity key for a snapshot based on its content,
  /// not its position. This ensures the same logical element always maps
  /// to the same DOM node.
  String _snapshotKey(Snapshot snap) {
    if (snap.type == SnapType.text) {
      return 'txt_${snap.text.hashCode}_${snap.fontSize.round()}';
    }
    if (snap.imageUrl != null) {
      return 'img_${snap.imageUrl.hashCode}';
    }
    // Box identity = just "box" — uniqueness comes from the keyCounter
    return 'box';
  }

  void _applyBorderSide(web.HTMLElement el, String side, BorderSide bs) {
    if (bs.width > 0 && bs.style != BorderStyle.none) {
      final c = bs.color;
      el.style.setProperty('border-$side',
          '${bs.width.toStringAsFixed(1)}px solid '
          // ignore: deprecated_member_use
          'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
    }
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _rescanTimer?.cancel();
    _rescanTimer = null;
    _lastSnapshotHash = 0; 
    _container?.remove();
    _container = null;
    _isListening = false;
  }
}