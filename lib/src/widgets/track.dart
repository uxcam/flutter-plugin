import 'package:flutter/material.dart';

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
    return child!;
  }
}
