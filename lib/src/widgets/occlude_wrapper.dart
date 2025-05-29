import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
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
      _updatePositionForTopRouteOnly();
    });
  }

  void _updatePosition() {
    if (!mounted) return;
    Rect rect = Rect.zero;
    if (OcclusionWrapperManager().containsWidgetByKey(_widgetKey)) {
      rect = _widgetKey.globalPaintBounds!;
    }
    OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
        _widgetKey, rect, _isWidgetInTopRoute());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositionForTopRouteOnly();
    });
  }

  void _updatePositionForTopRouteOnly() {
    if (!mounted) return;
    _updatePosition();
    // if (_isWidgetInTopRoute()) {
    //   _updatePosition();
    // }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
    OcclusionWrapperManager().add(
        DateTime.now().millisecondsSinceEpoch, _widgetKey, Rect.zero, false);
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
        _widgetKey, _widgetKey.globalPaintBounds!, _isWidgetInTopRoute());
  }

  void unRegisterOcclusionWidget() {
    // if (!_isWidgetInTopRoute()) {
    //   OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
    //   OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
    //       _widgetKey, _widgetKey.globalPaintBounds!, _isWidgetInTopRoute());
    // }
  }

  void hideOcclusionWidget() {
    if (!_isWidgetInTopRoute()) {
      //OcclusionWrapperManager().unRegisterOcclusionWrapper(_uniqueId);
      OcclusionWrapperManager().add(DateTime.now().millisecondsSinceEpoch,
          _widgetKey, _widgetKey.globalPaintBounds!, _isWidgetInTopRoute());
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
}

extension UtilIntExtension on double {
  int get ratioToInt {
    final bool isAndroid = Platform.isAndroid;
    final double pixelRatio =
        PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (this * (isAndroid ? pixelRatio : 1.0)).toInt();
  }
}
