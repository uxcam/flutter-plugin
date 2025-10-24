import 'package:flutter/material.dart';

class PixelGridOverlay extends StatelessWidget {
  final double pixelSize;
  const PixelGridOverlay({Key? key, this.pixelSize = 1.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PixelGridPainter(pixelSize),
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  final double pixelSize;
  _PixelGridPainter(this.pixelSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 0.5;

    for (double x = 0; x <= size.width; x += pixelSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += pixelSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
