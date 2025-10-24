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

  Rect? _lastRect;

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
  double? devicePixelRatio;
  BoundsTracker._() {
    devicePixelRatio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    SchedulerBinding.instance.addPersistentFrameCallback(_onPostFrame);
  }

  final Map<RenderBox, Rect> _rects = {};
  Map<RenderBox, Rect> get rects => Map.unmodifiable(_rects);

  void register(RenderBox box) {
    _rects[box] = Rect.zero;
  }

  void unRegister(RenderBox box) {
    _rects.remove(box);
  }

  void _onPostFrame(Duration timeStamp) {
    bool hasChanges = false;
    for (final entry in _rects.entries) {
      final box = entry.key;
      if (!box.attached) continue;
      final topLeft =
          box.localToGlobal(Offset.zero) * (devicePixelRatio ?? 1.0);
      final bottomRight =
          box.localToGlobal(Offset(box.size.width, box.size.height)) *
              (devicePixelRatio ?? 1.0);
      final rect = Rect.fromPoints(topLeft, bottomRight);
      final oldRect = entry.value;
      if (oldRect != rect) {
        _rects[box] = rect;
        hasChanges = true;
      }
      if (hasChanges) {
        print("gathered-rects: $_rects");
        notifyListeners();
      }
    }
  }
}
