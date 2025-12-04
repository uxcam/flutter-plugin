import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

extension GlobalKeyExtension on GlobalKey {
  Rect? get globalPaintBounds {
    var visibilityWidget =
        currentContext?.findAncestorWidgetOfExactType<Visibility>();
    if (visibilityWidget != null && !visibilityWidget.visible) {
      return null;
    }
    var opacityWidget =
        currentContext?.findAncestorWidgetOfExactType<Opacity>();
    if (opacityWidget != null && opacityWidget.opacity == 0) {
      return null;
    }

    final renderObject = currentContext?.findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      final bounds = renderObject!.paintBounds.shift(offset);
      return bounds;
    } else {
      return null;
    }
  }

  Route<dynamic>? _peekTopRoute(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return null;

    Route<dynamic>? top;
    navigator.popUntil((route) {
      top = route;
      return true; // stops immediately, nothing is popped
    });
    return top;
  }

  bool isWidgetVisible() {
    if (currentContext != null) {
      if (!currentContext!.mounted) return false;
      try {
        final route = ModalRoute.of(currentContext!);
        if (route == null) return false;

        if (route.isCurrent) {
          return true;
        }
        if (route.isActive) {
          final topRoute = _peekTopRoute(currentContext!);
          if (topRoute != null) {
            if (topRoute is PopupRoute && (topRoute).opaque == false) {
              return true; // dialog / dropdown / bottom sheet on top: keep occluding
            }
          }
        }
      } on FlutterError {
        return false;
      }
    }
    return false;
  }
}

extension UtilIntExtension on double {
  int get toNative {
    final bool isAndroid = Platform.isAndroid;
    final double pixelRatio =
        PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (this * (isAndroid ? pixelRatio : 1.0)).toInt();
  }

  int get toFlutter {
    final bool isAndroid = Platform.isAndroid;
    final double pixelRatio =
        PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (this / (isAndroid ? pixelRatio : 1.0)).toInt();
  }
}

extension ElementX on Element {
  bool isRendered() {
    final renderObject = this.renderObject;
    if (renderObject != null && renderObject is RenderBox) {
      if (!renderObject.hasSize) {
        return false;
      }
    } else {
      return false;
    }

    final visibility = findAncestorWidgetOfExactType<Visibility>();
    if (visibility != null && !visibility.visible) {
      return false;
    }
    final offstage = findAncestorWidgetOfExactType<Offstage>();
    if (offstage != null && offstage.offstage) {
      return false;
    }
    final opacity = findAncestorWidgetOfExactType<Opacity>();
    if (opacity != null && opacity.opacity == 0.0) {
      return false;
    }
    final animatedOpacity = findAncestorWidgetOfExactType<AnimatedOpacity>();
    if (animatedOpacity != null && animatedOpacity.opacity == 0.0) {
      return false;
    }

    return true;
  }

  bool targetListContainsElement(List<int>? targetList) {
    final renderObject = this.renderObject;
    if (renderObject != null && renderObject is RenderBox) {
      return targetList?.contains(renderObject.hashCode) ?? false;
    }
    return false;
  }

  String getUniqueId() {
    final slotInParent = this.slot;
    if (slotInParent != null) {
      final slot = (slotInParent as IndexedSlot).index;
      if (slot % 2 == 0) {}
    }
    return "";
  }

  Rect getEffectiveBounds() {
    Rect finalBounds = Rect.zero;
    if (this.renderObject is RenderBox) {
      final renderObject = this.renderObject as RenderBox;
      final translation = renderObject.getTransformTo(null).getTranslation();
      final offset = Offset(translation.x, translation.y);
      final bounds = renderObject.paintBounds.shift(offset);
      finalBounds = isRendered() ? bounds : Rect.zero;
    }
    return finalBounds;
  }

  Element? getSibling() {
    Element? sibling;
    if (slot is IndexedSlot) {
      final indexInParent = slot as IndexedSlot?;
      int siblingIndex = -1;
      if (indexInParent != null) {
        if (indexInParent.index % 2 == 0) {
          siblingIndex = indexInParent.index + 1;
        } else {
          siblingIndex = indexInParent.index - 1;
        }
      }
      visitAncestorElements((ancestor) {
        ancestor.visitChildren((element) {
          if (siblingIndex == (element.slot as IndexedSlot).index) {
            sibling = element;
            return;
          }
        });
        return false;
      });
    }
    return sibling;
  }
}

extension OptimizedElementX on Element {
  static final Map<int, Rect> _boundsCache = {};

  Rect getEffectiveBoundsOptimized() {
    final hashCode = renderObject?.hashCode ?? 0;
    if (hashCode == 0) return Rect.zero;

    final cached = _boundsCache[hashCode];
    if (cached != null) return cached;

    if (renderObject is RenderBox) {
      final renderBox = renderObject as RenderBox;
      if (!renderBox.hasSize) return Rect.zero;

      final translation = renderBox.getTransformTo(null).getTranslation();
      final bounds =
          renderBox.paintBounds.shift(Offset(translation.x, translation.y));

      // Cache with size limit
      if (_boundsCache.length > 100) {
        _boundsCache.clear();
      }
      _boundsCache[hashCode] = bounds;
      return bounds;
    }
    return Rect.zero;
  }
}
