import 'dart:ui';

import 'package:flutter/widgets.dart';

enum SnapType { text, box }

class Snapshot {
  final SnapType type;
  final double left;
  final double top;
  final double width;
  final double height;
  final int order;

  // Text fields
  final String? text;
  final double fontSize;
  final Color? fontColor;
  final FontWeight? fontWeight;

  // Box fields
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final BoxBorder? border;
  final String? imageUrl;

  Snapshot({
    required this.type,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.order,
    this.text,
    this.fontSize = 14.0,
    this.fontColor,
    this.fontWeight,
    this.color,
    this.borderRadius,
    this.border,
    this.imageUrl,
  });

  int get hashValue => Object.hash(
        type, text, imageUrl, left.round(), top.round(),
      );
}
