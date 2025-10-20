import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

class UxcamOverlay extends StatelessWidget {
  final Widget child;
  const UxcamOverlay({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ratio = View.of(context).devicePixelRatio;
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: Align(
            alignment: Alignment.bottomRight,
            child: AnimatedBuilder(
              animation: BoundsTracker.instance,
              builder: (context, _) {
                // Access all tracked rects
                print("object");
                final rects = BoundsTracker.instance.rects.values.toList();
                if (rects.isEmpty) {
                  return SizedBox.shrink();
                } else {
                  return Container(
                    width: 100,
                    height: 500,
                    child: Text(
                      rects.map((e) => e.toString()).join('\n'),
                      style: TextStyle(fontSize: 8),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

List<Color> encodeRect(Rect rect) {
  int x = rect.left.round();
  int y = rect.top.round();
  int w = rect.width.round();
  int h = rect.height.round();

  Color color1 = Color.fromARGB(255, x >> 8, x & 0xFF, y >> 8);
  Color color2 = Color.fromARGB(255, y & 0xFF, w >> 8, w & 0xFF);

  // Add a third color to store h fully
  Color color3 = Color.fromARGB(255, h >> 8, h & 0xFF, 0);

  return [color1, color2, color3];
}
