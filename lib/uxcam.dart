import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  final List<TrackData> _trackList = [];

  UxCam() {
    const BasicMessageChannel<Object?> uxCamMessageChannel =
        BasicMessageChannel<Object?>(
      'uxcam_message_channel',
      StandardMessageCodec(),
    );
    uxCamMessageChannel.setMessageHandler((message) async {
      final map = jsonDecode(message as String);
      final offset = Offset(
        (map["x"] as num).toDouble().toFlutter.toDouble(),
        (map["y"] as num).toDouble().toFlutter.toDouble(),
      );
      TrackData? _trackData;
      try {
        trackData = _trackList.firstWhere((data) {
          return data.bound.contains(offset);
        });
      } catch (e) {
        print("No track data found for offset: $offset");
      }
      if (trackData != null) {
        print("messagex: ${trackData.toString()}");
        return jsonEncode(trackData.toJson());
      }
      return "";
    });
  }

  addWidgetDataForTracking(TrackData data) {
    final id = data.uiId ?? "";
    _trackList.removeWhere((item) => item.uiId == id);
    _trackList.add(data);
  }

  updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }
}
