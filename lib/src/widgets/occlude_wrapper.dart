
import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_internal.dart';

class OccludeWrapper extends StatelessWidget {
  final Widget child;
  const OccludeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return OccludeWrapperInternal(
      child: child,
    );
  }
}
