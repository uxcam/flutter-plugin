import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OccludeWrapperAndroid extends StatefulWidget {
  final Widget child;

  const OccludeWrapperAndroid({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<OccludeWrapperAndroid> createState() => OccludeWrapperAndroidState();
}

class OccludeWrapperAndroidState extends State<OccludeWrapperAndroid>
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
    // Register widget after first frame is built
    registerOcclusionWidget();
    _updatePosition();
  }

  void _updatePosition() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Rect rect = Rect.zero;
      if (OcclusionWrapperManager().containsWidgetByKey(_widgetKey)) {
        rect = _widgetKey.globalPaintBounds ?? Rect.zero;
      }
      OcclusionWrapperManager()
          .add(DateTime.now().millisecondsSinceEpoch, _widgetKey, rect);
      _updatePosition();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
    OcclusionWrapperManager()
        .add(DateTime.now().millisecondsSinceEpoch, _widgetKey, Rect.zero);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _uniqueId,
      onVisibilityChanged: (VisibilityInfo visibilityInfo) {
        if (!mounted) return;
        final visibilityFraction = visibilityInfo.visibleFraction;
        if (visibilityFraction != 0) {
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
    OcclusionWrapperManager().registerOcclusionWrapper(item);
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
}
