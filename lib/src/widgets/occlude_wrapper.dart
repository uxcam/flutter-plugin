import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_android.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_ios.dart';

class OccludeWrapper extends StatelessWidget {
  final Widget child;
  const OccludeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return OccludeWrapperIos(
        child: child,
      );
    } else {
      return OccludeWrapperAndroid(
        child: child,
      );
    }
  }
}
