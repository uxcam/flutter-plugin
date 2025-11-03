import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class OccludeWrapper2 extends StatefulWidget {
  final Widget child;
  const OccludeWrapper2({Key? key, required this.child}) : super(key: key);

  @override
  State<OccludeWrapper2> createState() => _OccludeWrapper2State();
}

class _OccludeWrapper2State extends State<OccludeWrapper2> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeId = ModalRoute.of(context).hashCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Occlude(child: widget.child);
  }
}

class Occlude extends SingleChildRenderObjectWidget {
  const Occlude({Key? key, Widget? child}) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return OccludeBox();
  }
}

class OccludeBox extends RenderProxyBox {
  OccludeBox();

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

  final List<RenderBox> _occludedBoxes = [];
  List<OccludeBox> occludedBoxes() {
    // List<Rect> occupiedRegions = [];
    // List<RenderBox> result = [];
    // if (_occludedBoxes.isNotEmpty) {
    //   final reversed = _occludedBoxes.reversed.toList();
    //   for (final box in reversed) {
    //     if (!box.attached || !box.hasSize) continue;
    //     final Matrix4 m = box.getTransformTo(root);
    //     final Rect boxRect =
    //         MatrixUtils.transformRect(m, Offset.zero & box.size);
    //     if (occupiedRegions.isEmpty) {
    //       occupiedRegions.add(boxRect);
    //       result.add(box);
    //     } else {
    //       final isOccupied = occupiedRegions
    //           .where((rect) =>
    //               rect.contains(boxRect.topLeft) &&
    //               rect.contains(boxRect.bottomRight))
    //           .toList()
    //           .isNotEmpty;
    //       if (!isOccupied) {
    //         result.add(box);
    //       }
    //     }
    //   }
    //   for (final rect in occupiedRegions) {
    //     final hitTestResult = HitTestResult();
    //     WidgetsBinding.instance.hitTest(hitTestResult, rect.center);
    //     print("object:" + occupiedRegions.toString());
    //     hitTestResult.path.forEach((entry) {
    //       if (entry.target is OccludeBox) {
    //         final box = entry.target as OccludeBox;
    //         if (result.contains(box)) {
    //           result.remove(box);
    //         }
    //       }
    //     });
    //   }
    // }
    return List.unmodifiable(_occludedBoxes);
  }

  void register(RenderBox box) {
    _occludedBoxes.add(box);
  }

  void unRegister(RenderBox box) {
    _occludedBoxes.remove(box);
  }
}
