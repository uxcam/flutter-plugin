import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/screen_lifecycle.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OccludeWrapper extends StatefulWidget {
  final Widget child;

  const OccludeWrapper({
    Key? key,
    required this.child,
  });

  @override
  State<OccludeWrapper> createState() => _OccludeWrapperState();
}

class _OccludeWrapperState extends State<OccludeWrapper> with WidgetsBindingObserver {
  late OccludePoint occludePoint;
  final GlobalKey _widgetKey = GlobalKey();
  late final UniqueKey _uniqueId;
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
  void initState() {
    super.initState();
    _uniqueId = UniqueKey();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("Occlusion Rects: Widget added to occlusion list through initState.");
      registerOcclusionWidget();
      getOccludePoints();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debugPrint("Occlusion Rects: Widget removed from occlusion list through dispose.");
    unRegisterOcclusionWidget();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _uniqueId,
      onVisibilityChanged: (VisibilityInfo visibilityInfo) {
        final visibilityFraction = visibilityInfo.visibleFraction;
        if (visibilityFraction == 0) {
          debugPrint("Occlusion Rects: Widget removed from occlusion list through visibility.");
          unRegisterOcclusionWidget();
        } else {
          debugPrint("Occlusion Rects: Widget added to occlusion list through visibility.");
          registerOcclusionWidget();
        }
      },
      child: ScreenLifecycle(
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
      ),
    );
  }

  @override
  Future<bool> didPopRoute() {
    var didPop = super.didPopRoute();
    registerOcclusionWidget();
    return didPop;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    unRegisterOcclusionWidget();
    return super.didPushRouteInformation(routeInformation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

  }

  void getOccludePoint(Function(OccludePoint) rect) {
    var occludePoint = OccludePoint(0, 0, 0, 0);

    Rect? bound = _widgetKey.globalPaintBounds;

    if (bound == null) {
      rect(occludePoint);
      return;
    }

    occludePoint = OccludePoint(
      bound.left.ratioToInt,
      bound.top.ratioToInt,
      bound.right.ratioToInt,
      bound.bottom.ratioToInt,
    );

    rect(occludePoint);
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

  void registerOcclusionWidget() {
      var item = OcclusionWrapperItem(id: _uniqueId, key: _widgetKey);
      OcclusionWrapperManager().registerOcclusionWrapper(item);
  }

  void unRegisterOcclusionWidget() {
    OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
  }
}

extension GlobalKeyExtension on GlobalKey {
  Rect? get globalPaintBounds {
    
    var visibilityWidget = currentContext?.findAncestorWidgetOfExactType<Visibility>();
    if (visibilityWidget != null && !visibilityWidget.visible) {
      return null;
    }
    var opacityWidget = currentContext?.findAncestorWidgetOfExactType<Opacity>();
    if (opacityWidget != null && opacityWidget.opacity == 0) {
      return null;
    }
    var offstageWidget = currentContext?.findAncestorWidgetOfExactType<Offstage>();
    if (offstageWidget != null && offstageWidget.offstage) {
      return null;
    }

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

  Map<String, dynamic> toJson() {
    return {
      "x0": topLeftX,
      "y0": topLeftY,
      "x1": bottomRightX,
      "y1": bottomRightY,
    };
  }
}
