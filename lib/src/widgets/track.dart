import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/widgets/element_capture.dart';

class Track extends StatelessWidget {
  const Track({Key? key, this.ignoreGesture = false, required this.child})
      : super(key: key);

  final Widget child;
  final bool ignoreGesture;

  @override
  Widget build(BuildContext context) {
    Key? key;
    if (child.key != null)
      key = child.key;
    else
      key = GlobalKey();
    return ElementCapture(
      uiId: key.toString(),
      ignoreGesture: ignoreGesture,
      child: KeyedSubtree(
        key: key,
        child: child,
      ),
    );
  }
}
