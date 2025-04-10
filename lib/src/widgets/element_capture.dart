import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ElementCapture extends SingleChildRenderObjectWidget {
  final bool ignoreGesture;
  final String uiId;
  final String uiClass;

  const ElementCapture({
    Key? key,
    required this.ignoreGesture,
    required this.uiId,
    required this.uiClass,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return ElementCaptureRenderBox(ignoreGesture, uiId, uiClass);
  }

  @override
  void updateRenderObject(
      BuildContext context, ElementCaptureRenderBox renderObject) {
    renderObject.ignoreGesture = ignoreGesture;
    renderObject.uiId = uiId;
  }
}

class ElementCaptureRenderBox extends RenderProxyBox {
  bool ignoreGesture;
  String uiId;
  String uiClass;

  ElementCaptureRenderBox(this.ignoreGesture, this.uiId, this.uiClass);

  @override
  String toStringShort() {
    return 'ElementCaptureRenderBox(ignoreGesture: $ignoreGesture, uiId: $uiId,)';
  }
}
