import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:developer' as developer;

import 'package:flutter/scheduler.dart';

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
  List<RenderBox> get occludedBoxes => List.unmodifiable(_occludedBoxes);

  void register(RenderBox box) {
    _occludedBoxes.add(box);
  }

  void unRegister(RenderBox box) {
    _occludedBoxes.remove(box);
  }
}
