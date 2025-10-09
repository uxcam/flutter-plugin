import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OccludeWrapperOld extends StatefulWidget {
  final Widget child;

  const OccludeWrapperOld({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<OccludeWrapperOld> createState() => OccludeWrapperState();
}

class OccludeWrapperState extends State<OccludeWrapperOld>
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
    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try { await FlutterUxcam.attachBridge(); } catch (_) {}
        if (!mounted) return;
        registerOcclusionWidget();
      });
    } else {
      WidgetsBinding.instance.addPersistentFrameCallback((_) async {
        if (!mounted) return;
        _updatePositionForTopRouteOnly();
      });
    }
  }

  void _updatePositionForTopRouteOnly() {
    if (!mounted) return;
    _updatePosition();
  }

  void _updatePosition() {
    if (!mounted) return;
    Rect rect = Rect.zero;
    if (OcclusionWrapperManager().containsWidgetByKey(_widgetKey)) {
      rect = _widgetKey.globalPaintBounds ?? Rect.zero;
    }
    OcclusionWrapperManager()
        .add(DateTime.now().millisecondsSinceEpoch, _widgetKey, rect);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isIOS) {
      OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
    } else {
      OcclusionWrapperManager()
        .add(DateTime.now().millisecondsSinceEpoch, _widgetKey, Rect.zero);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _widgetKey,
      onVisibilityChanged: (VisibilityInfo visibilityInfo) {
        if (!mounted) return;
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
    if (!mounted) return;
    if (Platform.isIOS) {
      var item = OcclusionWrapperItem(id: _uniqueId, key: _widgetKey);
      OcclusionWrapperManager().registerOcclusionWrapper(item);
    } else {
      OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
        _widgetKey, _widgetKey.globalPaintBounds ?? Rect.zero);
    }
    
  }

  void unRegisterOcclusionWidget() {
    if (Platform.isIOS) {
      OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
    }
  }

  void hideOcclusionWidget() {
    if (!_isWidgetInTopRoute()) {
      OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
          _widgetKey, _widgetKey.globalPaintBounds!);
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
