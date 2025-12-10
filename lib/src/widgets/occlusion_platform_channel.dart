import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'occlusion_models.dart';

class OcclusionPlatformChannel {
  const OcclusionPlatformChannel();

  static const BasicMessageChannel<ByteData> _channel =
      BasicMessageChannel<ByteData>(
    'uxcam_occlusion_v2',
    BinaryCodec(),
  );

  /// Send batched occlusion updates to native side using a compact binary payload.
  ///
  /// Binary format:
  /// Header: [count:4 bytes]
  /// Per item: [viewId:4][id:4][left:4][top:4][right:4][bottom:4][type:1] = 25 bytes
  void sendBatchUpdate(List<OcclusionUpdate> updates) {
    if (updates.isEmpty) return;

    const headerSize = 4;
    const itemSize = 25;

    final buffer = ByteData(headerSize + updates.length * itemSize);

    buffer.setInt32(0, updates.length, Endian.little);

    var offset = headerSize;
    for (final update in updates) {
      buffer.setInt32(offset, update.viewId, Endian.little);
      buffer.setInt32(offset + 4, update.id, Endian.little);

      if (update.bounds != null) {
        final bounds = update.bounds!;
        final dpr = update.devicePixelRatio;

        buffer.setFloat32(offset + 8, bounds.left * dpr, Endian.little);
        buffer.setFloat32(offset + 12, bounds.top * dpr, Endian.little);
        buffer.setFloat32(offset + 16, bounds.right * dpr, Endian.little);
        buffer.setFloat32(offset + 20, bounds.bottom * dpr, Endian.little);
        buffer.setUint8(offset + 24, update.type.index);
      } else {
        buffer.setFloat32(offset + 8, -1.0, Endian.little);
        buffer.setFloat32(offset + 12, 0, Endian.little);
        buffer.setFloat32(offset + 16, 0, Endian.little);
        buffer.setFloat32(offset + 20, 0, Endian.little);
        buffer.setUint8(offset + 24, 0);
      }

      offset += itemSize;
    }

    _channel.send(buffer);
  }

  /// Send removal for a single occlusion.
  void sendRemoval(int id, int viewId) {
    const headerSize = 4;
    const itemSize = 25;

    final buffer = ByteData(headerSize + itemSize);

    buffer.setInt32(0, 1, Endian.little);
    buffer.setInt32(headerSize, viewId, Endian.little);
    buffer.setInt32(headerSize + 4, id, Endian.little);
    buffer.setFloat32(headerSize + 8, -1.0, Endian.little);

    _channel.send(buffer);
  }

  /// Clear all occlusions (e.g., when app is backgrounded).
  void clearAll() {
    final buffer = ByteData(4);
    buffer.setInt32(0, -1, Endian.little);
    _channel.send(buffer);
  }
}
