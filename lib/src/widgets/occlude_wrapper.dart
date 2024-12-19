import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/screen_lifecycle.dart';
import 'package:flutter_uxcam/src/widgets/occlude_warpper_manager.dart';

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
    getOccludePoints();
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
        unRegisterOcclusionWidget();
        cancelTimer();
      },
      onFocusGained: () {
        registerOcclusionWidget();
        startTimer();
      },
      child: Container(
        key: _widgetKey,
        child: widget.child,
      ),
    );
  }

  void registerOcclusionWidget() {
    var item = OcclusionWrapperItem(widget,_widgetKey);
    OcclusionWrapperManager.instance.registerOcclusionWrapper(item);
  }

  void unRegisterOcclusionWidget() {
    var item = OcclusionWrapperItem(widget,_widgetKey);
    OcclusionWrapperManager.instance.unRegisterOcclusionWrapper(item);
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

extension OccludeWrapperExtensions on OccludeWrapper {
  OccludePoint getOccludePoint(GlobalKey<State<StatefulWidget>> key) {

    var occludePoint = OccludePoint(0, 0, 0, 0);

    Rect? bound = key.globalPaintBounds;

    if (bound == null) return occludePoint;

    occludePoint = OccludePoint(
      bound.left.ratioToInt,
      bound.top.ratioToInt,
      bound.right.ratioToInt,
      bound.bottom.ratioToInt,
    );

    OcclusionWrapperManager.instance.updateOcclusionRects(occludePoint);

    return occludePoint;

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

  Map<String, int> toJson() {
    return {
      "x0": topLeftX,
      "y0": topLeftY,
      "x1": bottomRightX,
      "y1": bottomRightY,
    };
  }
}
