import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_ios.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_android.dart';

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
      return OccludeWrapperIos(
        key: key,
        child: child,
      );
    } else {
      return OccludeWrapperAndroid(
        key: key,
        child: child,
      );
    }
  }
}
