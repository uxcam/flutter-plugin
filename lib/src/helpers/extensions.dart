import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/widgets/track.dart';

extension WidgetX on Widget {
  Track track({bool ignoreGesture = false}) {
    return Track(ignoreGesture: ignoreGesture, child: this);
  }
}
