import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'occlusion_models.dart';

/// Serializes occlusion rects into the platform's expected wire format.
///
/// Shared by the wrapper/config occlusion entries and the auto text-field
/// rects so both go out identically. The platform decision is injectable so
/// tests can pin a format regardless of the host OS.
class OcclusionRectCodec {
  OcclusionRectCodec({bool? useIOSFormat})
      : _useIOSFormat = useIOSFormat ?? (!kIsWeb && Platform.isIOS);

  final bool _useIOSFormat;

  /// iOS expects logical-point corner coordinates; Android/web expect
  /// device-pixel edges plus id/type metadata.
  Map<String, dynamic> encode(
      int id, Rect bounds, double dpr, OcclusionType type) {
    if (_useIOSFormat) {
      return {
        'x0': bounds.left.toInt(),
        'y0': bounds.top.toInt(),
        'x1': bounds.right.toInt(),
        'y1': bounds.bottom.toInt(),
      };
    }
    return {
      'id': id,
      'left': (bounds.left * dpr).roundToDouble(),
      'top': (bounds.top * dpr).roundToDouble(),
      'right': (bounds.right * dpr).roundToDouble(),
      'bottom': (bounds.bottom * dpr).roundToDouble(),
      'type': type.index,
    };
  }
}
