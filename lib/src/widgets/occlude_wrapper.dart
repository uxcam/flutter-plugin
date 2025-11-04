import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_android.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_ios.dart';

class OccludeWrapper extends StatelessWidget {
  final Widget child;
  const OccludeWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return OccludeWrapperAndroid(child: child);
    } else {
      return OccludeWrapperIos(child: child);
    }
  }
}
