import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class OccludeWrapper2 extends SingleChildRenderObjectWidget {
  const OccludeWrapper2({Key? key, Widget? child})
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

class BoundsTracker extends ChangeNotifier {
  static final BoundsTracker instance = BoundsTracker._();
  BoundsTracker._();

  final List<OccludeBox> _occludedBoxes = [];

  List<OccludeBox> occludedBoxes() {
    return List.unmodifiable(_occludedBoxes.where((box) => box.isVisible));
  }

  void register(OccludeBox box) {
    _occludedBoxes.add(box);
  }

  void unRegister(OccludeBox box) {
    _occludedBoxes.remove(box);
  }
}
