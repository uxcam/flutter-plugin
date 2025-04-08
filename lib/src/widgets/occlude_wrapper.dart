import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/occlusion_event_collector.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class OccludeWrapper extends StatefulWidget {
  final Widget child;

  const OccludeWrapper({
    Key? key,
    required this.child,
  });

  @override
  State<OccludeWrapper> createState() => _OccludeWrapperState();
}

class _OccludeWrapperState extends State<OccludeWrapper>
    with WidgetsBindingObserver {
  final GlobalKey _widgetKey = GlobalKey();
  late final UniqueKey _uniqueId;

  @override
  void initState() {
    super.initState();
    _uniqueId = UniqueKey();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OcclusionEventCollector().streamNotifier.addListener(_sendRectData);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OcclusionEventCollector().streamNotifier.removeListener(_sendRectData);
    super.dispose();
  }

  void _sendRectData() {
    final point = getOccludePoints();
    if (point != null) {
      final _data = OccludeData(
        ModalRoute.of(context)?.runtimeType.toString(),
        ModalRoute.of(context)?.settings.name,
        point,
      );
      OcclusionEventCollector().emit(_data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _widgetKey,
      child: widget.child,
    );
  }

  OccludePoint? getOccludePoints() {
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
    var offstageWidget =
        currentContext?.findAncestorWidgetOfExactType<Offstage>();
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
