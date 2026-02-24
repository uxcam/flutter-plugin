import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

class WebTreeWalker {
  WebTreeWalker._();

  static final WebTreeWalker instance = WebTreeWalker._();

  // UUID management — persists across frames for stability
  int _uuidCounter = 0;
  final Map<String, String> _uuidCache = {};

  // Per-frame counter to disambiguate nodes with identical content keys
  Map<String, int> _keyCounter = {};

  /// Build an INodeMin tree from the Flutter element tree.
  /// Returns top-level nodes ready for uxcInjectSnapshot().
  List<Map<String, dynamic>> buildSnapshot(Element rootElement) {
    _keyCounter = {};
    return _walk(rootElement);
  }

  /// Get a stable UUID for a content-based key.
  /// Per-frame counter ensures duplicates get unique IDs.
  String _uuid(String contentKey) {
    final count = _keyCounter[contentKey] ?? 0;
    _keyCounter[contentKey] = count + 1;
    final uniqueKey = '${contentKey}_$count';
    return _uuidCache.putIfAbsent(uniqueKey, () => 'f_${_uuidCounter++}');
  }

  List<String> _baseStyle(Rect rect) => [
        'position:absolute',
        'left:${rect.left.toStringAsFixed(1)}px',
        'top:${rect.top.toStringAsFixed(1)}px',
        'width:${rect.width.toStringAsFixed(1)}px',
        'height:${rect.height.toStringAsFixed(1)}px',
      ];

  /// Returns the visible portion of [rect] after clipping to the browser
  /// viewport and any ancestor [clipBounds]. Returns null if completely
  /// outside the visible area.
  Rect? _visibleRect(Rect rect, {Rect? clipBounds}) {
    final viewWidth = web.window.innerWidth.toDouble();
    final viewHeight = web.window.innerHeight.toDouble();
    // Completely outside browser viewport
    if (rect.right <= 0 ||
        rect.left >= viewWidth ||
        rect.bottom <= 0 ||
        rect.top >= viewHeight) {
      return null;
    }
    // Completely outside ancestor clip bounds
    if (clipBounds != null) {
      if (rect.right <= clipBounds.left ||
          rect.left >= clipBounds.right ||
          rect.bottom <= clipBounds.top ||
          rect.top >= clipBounds.bottom) {
        return null;
      }
    }
    return rect;
  }

  Rect? _globalRect(RenderBox ro, Rect? clipBounds) {
    final transform = ro.getTransformTo(null);
    final translation = transform.getTranslation();
    final rect = ro.paintBounds.shift(Offset(translation.x, translation.y));
    return _visibleRect(rect, clipBounds: clipBounds);
  }

  Map<String, dynamic> _textINode(
    Rect rect,
    String text, {
    required double fontSize,
    Color? fontColor,
    FontWeight? fontWeight,
    required String contentKey,
  }) {
    final style = _baseStyle(rect);
    style.add('font-size:${fontSize.toStringAsFixed(1)}px');
    style.add('overflow:hidden');

    if (rect.height > fontSize * 1.8) {
      style.add('white-space:normal');
      style.add('line-height:${(fontSize * 1.4).toStringAsFixed(1)}px');
    } else {
      style.add('white-space:nowrap');
      style.add('line-height:${rect.height.toStringAsFixed(1)}px');
    }

    if (fontColor != null) style.add('color:${_css(fontColor)}');
    if (fontWeight != null && fontWeight != FontWeight.normal) {
      style.add('font-weight:${fontWeight.value}');
    }

    return {
      'nn': 'SPAN',
      't': 'SPAN',
      'nt': 1,
      'a': {'style': style.join(';')},
      'u': _uuid(contentKey),
      'c': <Map<String, dynamic>>[
        {
          'nn': '#text',
          't': '#text',
          'nt': 3,
          'a': {'textContent': text},
          'u': _uuid('${contentKey}_t'),
          'c': <Map<String, dynamic>>[],
          'r': <Map<String, dynamic>>[],
          's': false,
        }
      ],
      'r': <Map<String, dynamic>>[],
      's': false,
    };
  }

  /// Build a generic element INodeMin (DIV, etc).
  Map<String, dynamic> _elementNode(
      String tag, String uuid, List<String> style) {
    return {
      'nn': tag,
      't': tag,
      'nt': 1,
      'a': {'style': style.join(';')},
      'u': uuid,
      'c': <Map<String, dynamic>>[],
      'r': <Map<String, dynamic>>[],
      's': false,
    };
  }

  void _addSide(List<String> parts, String side, BorderSide bs) {
    if (bs.width > 0 && bs.style != BorderStyle.none) {
      parts.add(
          'border-$side:${bs.width.toStringAsFixed(1)}px solid ${_css(bs.color)}');
    }
  }

  String _css(Color c) =>
      'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})';

  String _borderRadiusCSS(BorderRadius br) => 'border-radius:'
      '${br.topLeft.x.toStringAsFixed(1)}px '
      '${br.topRight.x.toStringAsFixed(1)}px '
      '${br.bottomRight.x.toStringAsFixed(1)}px '
      '${br.bottomLeft.x.toStringAsFixed(1)}px';

  void _addBorderCSS(List<String> parts, Border b) {
    _addSide(parts, 'top', b.top);
    _addSide(parts, 'right', b.right);
    _addSide(parts, 'bottom', b.bottom);
    _addSide(parts, 'left', b.left);
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

  void resetUuids() {
    _uuidCache.clear();
    _uuidCounter = 0;
  }

  List<Map<String, dynamic>> _walk(Element element, {Rect? clipBounds, Offset parentOffset = Offset.zero,}) {
    final ro = element.renderObject;

    // Skip entire subtree if offstage or hidden
    if (ro is RenderOffstage && ro.offstage) return [];
    if (ro is RenderAnimatedOpacity && ro.opacity.value == 0.0) return [];
    if (ro is RenderOpacity && ro.opacity == 0.0) return [];

    // Accumulate clip bounds from clip render objects and scroll viewports.
    Rect? effectiveClip = clipBounds;

    if (ro is RenderClipPath && ro.hasSize) {
      final clipper = ro.clipper;
      Rect localClip;
      if (clipper != null) {
        localClip = clipper.getClip(ro.size).getBounds();
      } else {
        localClip = Offset.zero & ro.size;
      }
      if (localClip.width < 1.0 || localClip.height < 1.0) return [];
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip = localClip.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return [];
    }

    if (ro is RenderClipRect && ro.hasSize) {
      final clipper = ro.clipper;
      final localClip = clipper?.getClip(ro.size) ?? (Offset.zero & ro.size);
      if (localClip.width < 1.0 || localClip.height < 1.0) return [];
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip = localClip.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return [];
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
      if (effectiveClip.isEmpty) return [];
    }

    // Clip to scrollable viewport bounds (ListView, GridView, etc.)
    // RenderViewport clips content in its paint() method via clipBehavior,
    // not through a separate RenderClipRect — so we handle it explicitly.
    if (ro is RenderViewportBase &&
        ro.hasSize &&
        ro.clipBehavior != Clip.none) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip =
          ro.paintBounds.shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return [];
    }

    // RenderPhysicalShape / RenderPhysicalModel represent Material containers.
    // Always propagate their bounds as clip — even when clipBehavior == Clip.none,
    // CSS position:absolute children escape their parent without overflow:hidden.
    // Filtering children here also reduces snapshot payload.
    if (ro is RenderPhysicalShape && ro.hasSize) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip =
          (Offset.zero & ro.size).shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return [];
    }

    if (ro is RenderPhysicalModel && ro.hasSize) {
      final transform = ro.getTransformTo(null);
      final translation = transform.getTranslation();
      final globalClip =
          (Offset.zero & ro.size).shift(Offset(translation.x, translation.y));
      effectiveClip = effectiveClip?.intersect(globalClip) ?? globalClip;
      if (effectiveClip.isEmpty) return [];
    }

    // Skip entire subtree if this element's render object is a RepaintBoundary
    if (ro != null && ro.isRepaintBoundary) {
      // ignore: invalid_use_of_protected_member
      if (ro.layer != null && !(ro.layer?.attached ?? false)) return [];
    }

    Map<String, dynamic>? node;
    Offset nodeGlobalTopLeft = parentOffset;

    if (ro is RenderParagraph && ro.hasSize) {
      final text = ro.text.toPlainText();
      if (text.trim().isNotEmpty) {
        final rect = _globalRect(ro, effectiveClip);
        if (rect != null) {
          nodeGlobalTopLeft = rect.topLeft;
          final localRect = rect.shift(-parentOffset);
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

          node = _textINode(
            localRect,
            text,
            fontSize: fontSize ?? 14.0,
            fontColor: color,
            fontWeight: fontWeight,
            contentKey: 'txt_${text.hashCode}_${(fontSize ?? 14).round()}',
          );
        }
      }
    } else if (ro is RenderEditable && ro.hasSize) {
      final text = ro.text?.toPlainText() ?? '';
      if (text.trim().isNotEmpty) {
        final rect = _globalRect(ro, effectiveClip);
        if (rect != null) {
          nodeGlobalTopLeft = rect.topLeft;
          final localRect = rect.shift(-parentOffset);
          double? fontSize;
          Color? color;
          FontWeight? fontWeight;
          final span = ro.text;
          if (span is TextSpan && span.style != null) {
            fontSize = span.style!.fontSize;
            color = span.style!.color;
            fontWeight = span.style!.fontWeight;
          }
          node = _textINode(
            localRect,
            text,
            fontSize: fontSize ?? 14.0,
            fontColor: color,
            fontWeight: fontWeight,
            contentKey: 'edt_${text.hashCode}_${(fontSize ?? 14).round()}',
          );
        }
      }
    } else if (element.widget is InputDecorator &&
        ro is RenderBox &&
        ro.hasSize) {
      final rect = _globalRect(ro, effectiveClip);
      if (rect != null) {
        nodeGlobalTopLeft = rect.topLeft;
        final localRect = rect.shift(-parentOffset);
        final inputDeco = element.widget as InputDecorator;
        final decoration = inputDeco.decoration;
        final isFocused = inputDeco.isFocused;
        InputBorder? border = isFocused
            ? (decoration.focusedBorder ?? decoration.border)
            : (decoration.enabledBorder ?? decoration.border);
        border ??= const UnderlineInputBorder();

        final bColor = border.borderSide.color;
        final bWidth = border.borderSide.width;
        final style = _baseStyle(rect);

        if (border is OutlineInputBorder) {
          final br = border.borderRadius.resolve(TextDirection.ltr);
          style.add(
              'border:${bWidth.toStringAsFixed(1)}px solid ${_css(bColor)}');
          style.add(_borderRadiusCSS(br));
        } else {
          style.add(
              'border-bottom:${bWidth.toStringAsFixed(1)}px solid ${_css(bColor)}');
        }
        node = _elementNode('DIV', _uuid('input'), style);
      }
    } else if (ro is RenderDecoratedBox && ro.hasSize) {
      final decoration = ro.decoration;
      if (decoration is BoxDecoration) {
        // Only capture if there's something visible (color or border)
        if (decoration.color != null || decoration.border != null) {
          final rect = _globalRect(ro, effectiveClip);
          if (rect == null) return [];

          nodeGlobalTopLeft = rect.topLeft;
          final style = _baseStyle(rect.shift(-parentOffset));
          if (decoration.color != null) {
            style.add('background-color:${_css(decoration.color!)}');
          }
          if (decoration.borderRadius != null) {
            style.add(_borderRadiusCSS(
                decoration.borderRadius!.resolve(TextDirection.ltr)));
          }
          if (decoration.border is Border) {
            _addBorderCSS(style, decoration.border! as Border);
          }

          node = _elementNode('DIV', _uuid('dbox'), style);
        }
      }
    } else if (element.widget is ColoredBox && ro is RenderBox && ro.hasSize) {
      final rect = _globalRect(ro, effectiveClip);
      if (rect != null) {
        nodeGlobalTopLeft = rect.topLeft;
        final style = _baseStyle(rect.shift(-parentOffset));
        style.add(
            'background-color:${_css((element.widget as ColoredBox).color)}');
        node = _elementNode('DIV', _uuid('cbox'), style);
      }
    } else if (ro is RenderPhysicalShape && ro.hasSize) {
      final rect = _globalRect(ro, effectiveClip);
      if (rect != null) {
        nodeGlobalTopLeft = rect.topLeft;
        final style = _baseStyle(rect.shift(-parentOffset));
        style.add('background-color:${_css(ro.color)}');

        final clipper = ro.clipper;
        if (clipper is ShapeBorderClipper) {
          final shape = clipper.shape;
          if (shape is RoundedRectangleBorder) {
            style.add(_borderRadiusCSS(
                shape.borderRadius.resolve(TextDirection.ltr)));
          }
        }

        // Always clip in CSS — even when Flutter uses Clip.none, position:absolute
        // children would escape their parent bounds without overflow:hidden.
        style.add('overflow:hidden');

        node = _elementNode('DIV', _uuid('pshape'), style);
      }
    } else if (ro is RenderPhysicalModel && ro.hasSize) {
      final rect = _globalRect(ro, effectiveClip);
      if (rect != null) {
        nodeGlobalTopLeft = rect.topLeft;
        final style = _baseStyle(rect.shift(-parentOffset));
        style.add('background-color:${_css(ro.color)}');

        if (ro.borderRadius != null && ro.borderRadius != BorderRadius.zero) {
          style.add(
              _borderRadiusCSS(ro.borderRadius!.resolve(TextDirection.ltr)));
        }

        style.add('overflow:hidden');

        node = _elementNode('DIV', _uuid('pmodel'), style);
      }
    } else if (ro is RenderImage && ro.hasSize) {
      final rect = _globalRect(ro, effectiveClip);
      if (rect == null) return [];

      nodeGlobalTopLeft = rect.topLeft;

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
            return false;
          }
          return true;
        });
      }

      if (url != null) {
        final parentUuid = _uuid('img_${url.hashCode}');
        final imgUuid = _uuid('img_el_${url.hashCode}');

        node = {
          'nn': 'DIV',
          't': 'DIV',
          'nt': 1,
          'a': {'style': _baseStyle(rect.shift(-parentOffset)).join(';')},
          'u': parentUuid,
          'c': <Map<String, dynamic>>[
            {
              'nn': 'IMG',
              't': 'IMG',
              'nt': 1,
              'a': {
                'src': url,
                'style': 'width:100%;height:100%;object-fit:cover',
              },
              'u': imgUuid,
              'c': <Map<String, dynamic>>[],
              'r': <Map<String, dynamic>>[],
              's': false,
            }
          ],
          'r': <Map<String, dynamic>>[],
          's': false,
        };
      }
    }

    final childParentOffset =
        (node != null) ? nodeGlobalTopLeft : parentOffset;

    final childNodes = <Map<String, dynamic>>[];
    element.visitChildElements((child) {
      childNodes.addAll(_walk(child, clipBounds: effectiveClip, parentOffset: childParentOffset));
    });

    if (node != null) {
      // This element produced a node — nest children inside it
      (node['c'] as List<Map<String, dynamic>>).addAll(childNodes);
      return [node];
    }

    // Pass-through: no visual output from this element, forward children
    return childNodes;
  }
}
