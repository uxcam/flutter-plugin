import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager_ios.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OccludeWrapperIos extends StatefulWidget {
  final Widget child;

  const OccludeWrapperIos({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<OccludeWrapperIos> createState() => OccludeWrapperIosState();
}

class OccludeWrapperIosState extends State<OccludeWrapperIos>
    with WidgetsBindingObserver {
  late OccludePoint occludePoint;
  late final GlobalKey _widgetKey;
  late final UniqueKey _uniqueId;

  @override
  void initState() {
    super.initState();
    _uniqueId = UniqueKey();
    _widgetKey = GlobalKey();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Register widget after first frame is built
      if (!mounted) return;
      registerOcclusionWidget();
      try {
        await FlutterUxcam.attachBridge();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OcclusionWrapperManagerIOS().unRegisterOcclusionWrapper(_uniqueId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _uniqueId,
      onVisibilityChanged: (VisibilityInfo visibilityInfo) {
        if (!mounted) return;
        final visibilityFraction = visibilityInfo.visibleFraction;
        if (visibilityFraction == 0) {
          hideOcclusionWidget();
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
    if (!mounted) return;
    var item = OcclusionWrapperItem(id: _uniqueId, key: _widgetKey);
    OcclusionWrapperManagerIOS().registerOcclusionWrapper(item);
  }

  void unRegisterOcclusionWidget() {
    if (Platform.isIOS)
      OcclusionWrapperManagerIOS().unRegisterOcclusionWrapper(_uniqueId);
  }

  void hideOcclusionWidget() {
    if (!_isWidgetInTopRoute()) {
      OcclusionWrapperManagerIOS().unRegisterOcclusionWrapper(_uniqueId);
    }
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

  bool _isWidgetInTopRoute() {
    if (!mounted) return false;
    try {
      ModalRoute? modalRoute = ModalRoute.of(context);
      return modalRoute != null && modalRoute.isCurrent && modalRoute.isActive;
    } on FlutterError {
      return false;
    }
  }
}
