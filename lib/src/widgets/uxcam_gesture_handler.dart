

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/models/gesture_handler.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

Element? _clickTrackerElement;

class UXCamGestureHandler extends StatefulWidget {
  const UXCamGestureHandler({Key? key, required this.child, this.types = const []})
      : super(key: key);

  final Widget child;
  final List<Type> types;

  @override
  StatefulElement createElement() {
    final element = super.createElement();
    _clickTrackerElement = element;
    return element;
  }

  @override
  State<UXCamGestureHandler> createState() => _UXCamGestureHandlerState();
}

class _UXCamGestureHandlerState extends State<UXCamGestureHandler> {

  late GestureHandler gestureHandler;
  int? _lastPointerId;
  Offset? _lastPointerDownLocation;
  TrackData? _lastTrackData;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (details) => _onTappedAt(context, details.localPosition), 
      child: widget.child,   
    );
      // return GestureDetector(
      //   behavior: HitTestBehavior.translucent,
      //   onTapDown: (details) => _onTappedAt(context, details.globalPosition),
      //   onDoubleTapDown: (details) => _onTappedAt(context, details.globalPosition),
      //   onLongPressStart: (details) => _onTappedAt(context, details.globalPosition), 
      //   child: widget.child,  
      // );  
  }

  void _onTappedAt(BuildContext context, Offset position) {
     context.visitChildElements(
      (element) {
        gestureHandler.inspectElement(element);
        gestureHandler.notifyTrackDataAt(position);
      }
     );
  }

}