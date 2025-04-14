import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/element_capture.dart';

class UxCamBinding extends WidgetsFlutterBinding {
  @override
  void initInstances() {
    super.initInstances();
    pointerRouter.addGlobalRoute((PointerEvent event) {
      if (event is PointerDownEvent) {
        _onDown(event);
      }
    });
  }

  void _onDown(PointerDownEvent event) {
    final result = HitTestResult();
    bool isIgnoreGesture = false;
    String uiID = "";
    String uiName = "";
    String uiType = "";
    String uiClass = "";
    RendererBinding.instance.hitTest(result, event.position);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderParagraph) {
        final span = target.text;
        if (span is TextSpan) {
          uiName = span.toPlainText();
        }
      }
      // if (target is ElementCaptureRenderBox) {
      //   uiID = target.uiId;
      //   isIgnoreGesture = target.ignoreGesture;
      //   uiClass = target.uiClass;
      // }
      print(
          "Captured information: id: $uiID, name: $uiName, uiType: $uiType, uiClass: $uiClass");
    }
  }
}
