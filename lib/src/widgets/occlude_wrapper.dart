import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OccludeWrapper extends StatefulWidget {
  final Widget child;

  const OccludeWrapper({
    Key? key,
    required this.child,
  });

  @override
  State<OccludeWrapper> createState() => OccludeWrapperState();
}

class OccludeWrapperState extends State<OccludeWrapper>
    with WidgetsBindingObserver {
  late OccludePoint occludePoint;
  final GlobalKey _widgetKey = GlobalKey();
  late final UniqueKey _uniqueId;
  Offset? lastPosition;

  @override
  void initState() {
    super.initState();
    _uniqueId = UniqueKey();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      registerOcclusionWidget();
      _updatePosition();
    });
  }

  void _updatePosition() {
    if (!mounted) return;
    OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
        _widgetKey, _widgetKey.globalPaintBounds!);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updatePosition();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          unRegisterOcclusionWidget();
        } else {
          registerOcclusionWidget();
        }
      },
      child: Container(
        key: _widgetKey,
        child: widget.child,
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

  void registerOcclusionWidget() {
    var item = OcclusionWrapperItem(id: _uniqueId, key: _widgetKey);
    OcclusionWrapperManager().registerOcclusionWrapper(item);
  }

  void unRegisterOcclusionWidget() {
    OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
    OcclusionWrapperManager()
        .add(DateTime.now().millisecondsSinceEpoch, _widgetKey, Rect.zero);
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
}

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
    // if (offstageWidget != null) {
    //   return null;
    // }

    final renderObject = currentContext?.findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      final bounds = renderObject!.paintBounds.shift(offset);
      final isLandscape =
          MediaQuery.of(currentContext!).orientation == Orientation.landscape;
      if (isLandscape) {
        final padding = MediaQuery.of(currentContext!).padding;
        //some devices (tested on samsung a5), have a top system overlay for gesture detection. This effects the screenshot taken from native
        //Android. As a consequence, we need to add the systemGestureInsets to the top of the bounds, to offset the occlusion rects when in landscape.
        final systemGestureInsets =
            MediaQuery.of(currentContext!).systemGestureInsets;
        if (padding.left != 0) {
          return bounds.translate(padding.left, 0.0);
        } else {
          if (systemGestureInsets.top != 0.0) {
            final _scale = MediaQuery.of(currentContext!).textScaler !=
                    TextScaler.noScaling
                ? MediaQuery.of(currentContext!).devicePixelRatio.toInt()
                : 0;
            return bounds.translate(systemGestureInsets.top * _scale, 0.0);
          }
        }
      }
      return bounds;
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
