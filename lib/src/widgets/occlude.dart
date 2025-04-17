import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_manager.dart';

class Occlude extends SingleChildRenderObjectWidget {
  Occlude({
    Key? key,
    required this.child,
  }) : super(key: key, child: child);

  final Widget child;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOcclude(key as GlobalKey?);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderOcclude renderObject) {}
}

class _RenderOcclude extends RenderProxyBox {
  bool _isAttached = false;
  _RenderOcclude(GlobalKey? key) {
    this.key = key ?? GlobalKey();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_isAttached) {
        _updateLayout();
      }
    });
  }

  GlobalKey? key;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _isAttached = true;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _updateLayout();
  }

  void _updateLayout() {
    final translation = getTransformTo(null).getTranslation();
    final globalOffset = Offset(translation.x, translation.y);

    if (key != null) {
      OcclusionManager().add(
          DateTime.now().millisecondsSinceEpoch, key!, globalOffset & size);
    } else {
      print("The occlude widget requires a key for position tracking");
    }
  }

  @override
  void detach() {
    _isAttached = false;
    super.detach();
  }
}
