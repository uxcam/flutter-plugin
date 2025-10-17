import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class UxcamOverlay extends StatelessWidget {
  final Widget child;
  const UxcamOverlay({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ratio = ui.window.devicePixelRatio;
    return Stack(
      children: [
        child,
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: 10 / ratio,
            height: 10 / ratio,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}
