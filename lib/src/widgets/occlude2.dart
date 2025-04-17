import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_manager.dart';

class Occlude extends StatefulWidget {
  const Occlude({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<Occlude> createState() => _OccludeState();
}

class _OccludeState extends State<Occlude> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updatePosition();
    });
  }

  void _updatePosition() {
    final timestamp = SchedulerBinding.instance.currentFrameTimeStamp;
    Key? key = widget.key ?? GlobalKey();
    (key as GlobalKey).globalPaintBounds;
    OcclusionManager()
        .add(timestamp.inMilliseconds, key, (key).globalPaintBounds!);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updatePosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
