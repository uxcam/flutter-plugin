import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OccludeWrapper extends StatefulWidget {
  final Widget child;

  const OccludeWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<OccludeWrapper> createState() => OccludeWrapperState();
}

class OccludeWrapperState extends State<OccludeWrapper>
    with WidgetsBindingObserver {
  late OccludePoint occludePoint;
  late final GlobalKey _widgetKey;
  late final UniqueKey _uniqueId;
  Offset? lastPosition;

  @override
  void initState() {
    super.initState();
    _uniqueId = UniqueKey();
    _widgetKey = GlobalKey();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      registerOcclusionWidget();
      _checkPosition();
    });
  }

  void _checkPosition() {
    if (mounted) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        final position = renderObject.localToGlobal(Offset.zero);
        Future.delayed(
          const Duration(milliseconds: 1),
          () {
            OcclusionWrapperManager()
                .addNewBound(_uniqueId, _widgetKey.globalPaintBounds!);
          },
        );

        lastPosition = position;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkPosition());
    }
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
          //hideOcclusionWidget();
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
    OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
        _widgetKey, _widgetKey.globalPaintBounds!);
  }

  void unRegisterOcclusionWidget() {
    OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
  }

  void getOccludePoint(Function(OccludePoint) rect) {
    var occludePoint = OccludePoint(0, 0, 0, 0);

    Rect? bound = _widgetKey.globalPaintBounds;

    if (bound == null) {
      rect(occludePoint);
      return;
    }

    occludePoint = OccludePoint(
      bound.left.toNative,
      bound.top.toNative,
      bound.right.toNative,
      bound.bottom.toNative,
    );

    rect(occludePoint);
  }

  void getOccludePoints() {
    // Preventing Extra Operation
    if (!mounted) return;

    Rect? bound = _widgetKey.globalPaintBounds;

    if (bound == null) return;

    occludePoint = OccludePoint(
      bound.left.toNative,
      bound.top.toNative,
      bound.right.toNative,
      bound.bottom.toNative,
    );

    FlutterUxcam.occludeRectWithCoordinates(
      occludePoint.topLeftX,
      occludePoint.topLeftY,
      occludePoint.bottomRightX,
      occludePoint.bottomRightY,
    );
  }

  OccludePoint? getOccludePointsForStream() {
    // Preventing Extra Operation
    if (!mounted) return null;

    Rect? bound = _widgetKey.globalPaintBounds;

    if (bound == null) return null;

    return OccludePoint(
      bound.left.ratioToInt,
      bound.top.ratioToInt,
      bound.right.ratioToInt,
      bound.bottom.ratioToInt,
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
            return bounds.translate(systemGestureInsets.top, 0.0);
          }
        }
      }
      return bounds;
    } else {
      return null;
    }
  }
}
