import 'dart:io';
import 'dart:ui';

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
    // var offstageWidget =
    //     currentContext?.findAncestorWidgetOfExactType<Offstage>();
    // if (offstageWidget != null && offstageWidget.offstage) {
    //   return null;
    // }

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

  bool isWidgetVisible() {
    if (currentContext != null) {
      if (!currentContext!.mounted) return false;
      try {
        ModalRoute? modalRoute = ModalRoute.of(currentContext!);
        return modalRoute != null &&
            modalRoute.isCurrent &&
            modalRoute.isActive;
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
