import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

double _tapDeltaArea = 32.0 * 32.0; // 32 pixels squared
Element? _clickTrackerElement;

class UXCamGestureHandler extends StatefulWidget {
  const UXCamGestureHandler(
      {Key? key, required this.child, this.types = const []})
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
  int? _lastPointerId;
  Offset? _lastPointerDownLocation;
  TrackData? _lastTrackData;

  List<Type> userDefinedTypes = [];

  List<Type> knownButtonTypes = [
    ElevatedButton,
    TextButton,
    OutlinedButton,
    GestureDetector,
    InkWell,
    IconButton,
    FloatingActionButton,
  ];

  List<Type> nonInteractiveTypes = [
    Image,
    Text,
    RichText,
    Icon,
  ];

  List<Type> fieldTypes = [
    TextField,
    TextFormField,
  ];

  List<Type> containerTypes = [Scaffold];

  List<Type> overlayTypes = [
    BottomSheet,
    Dialog,
  ];

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    try {
      _lastPointerId = event.pointer;
      _lastPointerDownLocation = event.localPosition;
    } catch (exception, stacktrace) {
      print("Error in pointer up: $exception");
      print("Stacktrace: $stacktrace");
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    try {
      // Figure out if something was tapped
      final location = _lastPointerDownLocation;
      if (location == null || event.pointer != _lastPointerId) {
        return;
      }
      final delta = Offset(
        location.dx - event.localPosition.dx,
        location.dy - event.localPosition.dy,
      );

      if (delta.distanceSquared < _tapDeltaArea) {
        _onTappedAt(event.localPosition);
      }
    } catch (exception, stacktrace) {
      print("Error in pointer up: $exception");
      print("Stacktrace: $stacktrace");
    }
  }

  void _onTappedAt(Offset position) {
    TrackData? data = _getElementDataAt(position);
    if (data != null) {
      _lastTrackData = data;
      FlutterUxcam.appendGestureContent(position, _lastTrackData!);
      _lastTrackData = null;
    } else {
      _lastTrackData = null;
    }
  }

  TrackData? _getElementDataAt(Offset position) {
    final rootElement = _clickTrackerElement;
    if (rootElement == null || rootElement.widget != widget) {
      return null;
    }

    TrackData? trackData;

    void elementFinder(Element element) {
      if (trackData != null) return; // Stop searching if we found a match

      final renderObject = element.renderObject;
      if (renderObject == null) return;

      final elementBounds = _getRectFromBox(renderObject as RenderBox);

      if (!elementBounds.contains(position)) {
        return;
      }
      if (widget.types.isNotEmpty &&
          !widget.types.contains(element.widget.runtimeType)) {
        return;
      }

      var hitFound = true;
      if (renderObject is RenderPointerListener) {
        final hitResult = BoxHitTestResult();
        // Returns false if the hit can continue to other objects below this one.
        hitFound = renderObject.hitTest(hitResult, position: position);
      }

      trackData = _dataForWidget(element, elementBounds);

      if (trackData == null || !hitFound) {
        element.visitChildElements(elementFinder);
      }
    }

    rootElement.visitChildElements(elementFinder);
    return trackData;
  }

  TrackData? _dataForWidget(Element element, Rect bound) {
    String route = ModalRoute.of(element)?.settings.name ?? "";
    if (route == "") route = "/";

    if (element.widget.key == null) {
      return null; // Skip for non-keyed widgets
    }

    String uiId = element.widget.key.toString();

    int uiType = -1;
    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      uiType = 1;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      uiType = 2;
    }
    if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      if (element.widget.runtimeType.toString() == "Text" ||
          element.widget.runtimeType.toString() == "RichText") {
        uiType = 7;
      }
      if (element.widget.runtimeType.toString() == "Image" ||
          element.widget.runtimeType.toString() == "Icon") {
        uiType = 12;
      }
    }
    if (containerTypes.contains(element.widget.runtimeType)) {
      uiType = 5;
    }

    if (uiType == -1 && widget.types.isNotEmpty) {
      return null; // Skip if the widget type is not in the user-defined types
    }

    return TrackData(
      bound,
      route,
      uiClass: element.widget.runtimeType.toString(),
      uiId: uiId,
      uiType: uiType,
    );
  }

  Rect _getRectFromBox(RenderBox renderObject) {
    final translation = renderObject.getTransformTo(null).getTranslation();
    final offset = Offset(translation.x, translation.y);
    final bounds = renderObject.paintBounds.shift(offset);
    return bounds;
  }
}
