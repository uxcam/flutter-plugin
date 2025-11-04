import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_uxcam/src/models/bound_tracker.dart';

class OccludeWrapperAndroid extends SingleChildRenderObjectWidget {
  const OccludeWrapperAndroid({Key? key, Widget? child})
      : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    final route = ModalRoute.of(context);
    return OccludeBox(route != null && route.isCurrent && route.isActive);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant OccludeBox renderObject) {
    final route = ModalRoute.of(context);
    renderObject.isVisible = route != null && route.isCurrent && route.isActive;
  }
}

class OccludeBox extends RenderProxyBox {
  bool isVisible;
  OccludeBox(this.isVisible);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    BoundsTracker.instance.register(this);
  }

  @override
  void detach() {
    super.detach();
    BoundsTracker.instance.unRegister(this);
  }
}
