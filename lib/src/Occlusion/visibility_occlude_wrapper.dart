import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/Occlusion/special_widget_wrapper.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_old.dart';

// Drop-in replacement for OccludeWrapper using VisibilityTracker
class OccludeWrapper extends StatelessWidget {
  final Widget child;

  const OccludeWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return OccludeWrapperOld(
        key: key,
        child: child,
      );
    }
    else {
      return  SpecialWidget(
        key: key,
        child: child,
      );
    }
  }
} 