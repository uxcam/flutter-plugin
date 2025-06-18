import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  List<TrackData> _trackList = [];

  UxCam() {
    const BasicMessageChannel<Object?> uxCamMessageChannel =
        BasicMessageChannel<Object?>(
      'uxcam_message_channel',
      StandardMessageCodec(),
    );
    uxCamMessageChannel.setMessageHandler((message) async {
      final map = jsonDecode(message as String);
      final offset = Offset(
        (map["x"] as int).toDouble().toFlutter.toDouble(),
        (map["y"] as int).toDouble().toFlutter.toDouble(),
      );
      print("messagex: $offset");
      TrackData? _trackData;
      try {
        _trackData = _trackList.firstWhere((data) {
          return data.bound.contains(offset);
        });
      } catch (e) {}
      if (_trackData != null) {
        print("messagex: ${_trackData.toString()}");
        return jsonEncode(_trackData.toJson());
      }
      return "";
    });
  }

  addWidgetDataForTracking(TrackData data) {
    final id = data.uiId ?? "";
    _trackList.removeWhere((item) => item.uiId == id);
    _trackList.add(data);
  }
}
