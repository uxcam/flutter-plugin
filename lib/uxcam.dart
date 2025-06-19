import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  List<TrackData> _trackList = [];
  String _topRoute = "/";

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

      TrackData? _trackData;
      try {
        _trackData = _trackList.lastWhere((data) {
          return data.bound.contains(offset);
        });
      } catch (e) {}
      print("messagex:" + offset.toString());
      print("messagex:" + _trackList.toString());
      if (_trackData != null) {
        if (_trackData.route != _topRoute) {
          return "";
        }

        if (_trackData.route == "/") {
          _trackData.route = "root";
          if (_trackData.uiId != null) {
            _trackData.uiId =
                "root" + _trackData.uiId!.substring(1, _trackData.uiId!.length);
          }
        }
        if (_trackData.uiId != null && _trackData.uiId!.startsWith("/")) {
          _trackData.uiId =
              _trackData.uiId!.substring(1, _trackData.uiId!.length);
        }
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

  updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }
}
