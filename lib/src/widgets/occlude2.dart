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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      if (route.isCurrent && route.isActive) {
        //this widget is visible
        BoundsTracker.instance.updateRouteHistory(route.hashCode);
      } else {
        //this widget is no longer visible
        BoundsTracker.instance.popTopRoute();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Occlude(
      child: widget.child,
      routeId: ModalRoute.of(context).hashCode,
    );
  }
}

class Occlude extends SingleChildRenderObjectWidget {
  final int? routeId;
  const Occlude({
    Key? key,
    Widget? child,
    this.routeId,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return OccludeBox(routeId ?? -1);
  }
}

class OccludeBox extends RenderProxyBox {
  int routeId;
  OccludeBox(this.routeId);

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

  final Map<OccludeBox, bool> _boxVisibility = {};

  void updateBoxVisibility(OccludeBox box, bool isVisible) {
    _boxVisibility[box] = isVisible;
  }

  List<OccludeBox> occludedBoxes() {
    if (_occludedBoxes.isNotEmpty) {
      final filtered = _occludedBoxes
          .where((OccludeBox box) {
            return box.routeId == getTopRoute();
          })
          .cast<OccludeBox>()
          .toList();
      return filtered;
    }
    return List.unmodifiable(_occludedBoxes);
  }

  void register(OccludeBox box) {
    _occludedBoxes.add(box);
  }

  void unRegister(OccludeBox box) {
    _occludedBoxes.remove(box);
  }
}
