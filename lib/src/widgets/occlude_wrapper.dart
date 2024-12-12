import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/screen_lifecycle.dart';

class OccludeWrapper extends StatefulWidget {
  final Widget child;

  const OccludeWrapper({
    Key? key,
    required this.child,
  });

  @override
  State<OccludeWrapper> createState() => _OccludeWrapperState();
}

class _OccludeWrapperState extends State<OccludeWrapper> {
  late OccludePoint occludePoint;
  final GlobalKey _widgetKey = GlobalKey();
  Timer? _timer = null;

  void startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      getOccludePoints();
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    FlutterUxcam.occludeRectWithCoordinates(0, 0, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLifecycle(
      onFocusLost: () {
        cancelTimer();
      },
      onFocusGained: () {
        startTimer();
      },
      child: Container(
        key: _widgetKey,
        child: widget.child,
      ),
    );
  }

  void getOccludePoints() {
    // Preventing Extra Operation
    if (!mounted) return;

    Rect? bound = _widgetKey.globalPaintBounds;

    if (bound == null) return;

    occludePoint = OccludePoint(
      bound.left.ratioToInt,
      bound.top.ratioToInt,
      bound.right.ratioToInt,
      bound.bottom.ratioToInt,
    );

    FlutterUxcam.occludeRectWithCoordinates(
      occludePoint.topLeftX,
      occludePoint.topLeftY,
      occludePoint.bottomRightX,
      occludePoint.bottomRightY,
    );
  }
}

extension GlobalKeyExtension on GlobalKey {
  Rect? get globalPaintBounds {
    final renderObject = currentContext?.findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      return renderObject!.paintBounds.shift(offset);
    } else {
      return null;
    }
  }
}

extension UtilIntExtension on double {
  int get ratioToInt {
    final bool isAndroid = Platform.isAndroid;
    final double pixelRatio =
        PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (this * (isAndroid ? pixelRatio : 1.0)).toInt();
  }
}

class OccludePoint {
  int topLeftX;
  int topLeftY;
  int bottomRightX;
  int bottomRightY;

  OccludePoint(
    this.topLeftX,
    this.topLeftY,
    this.bottomRightX,
    this.bottomRightY,
  );

  @override
  String toString() {
    return 'OccludePoint(topLeftX: $topLeftX, topLeftY: $topLeftY, bottomRightX: $bottomRightX, bottomRightY: $bottomRightY)';
  }
}
