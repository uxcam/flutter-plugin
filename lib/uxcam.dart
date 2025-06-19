import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/helpers/extensions.dart';
import 'package:flutter_uxcam/src/models/track_data.dart';

class UxCam {
  static FlutterUxcamNavigatorObserver? navigationObserver;
  List<TrackData> _trackList = [];

  String _topRoute = "/";
  String get topRoute => _topRoute;

  UxCam() {
    const BasicMessageChannel<Object?> uxCamMessageChannel =
        BasicMessageChannel<Object?>(
      'uxcam_message_channel',
      StandardMessageCodec(),
    );
    uxCamMessageChannel.setMessageHandler((message) async {
      print("flat tree:" + _trackList.toString());

      final map = jsonDecode(message as String);
      final offset = Offset(
        (map["x"] as num).toDouble().toFlutter.toDouble(),
        (map["y"] as num).toDouble().toFlutter.toDouble(),
      );
      print("messagex: $offset");
      TrackData? _trackData;
      try {
        trackData = _trackList.firstWhere((data) {
          return data.bound.contains(offset);
        }).copy();
      } catch (e) {}
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
        print("messagey:" + _trackData.toString());
        return jsonEncode(_trackData.toJson());
      }
      return "";
    });
  }

  addWidgetDataForTracking(TrackData data) {
    final id = data.uiId ?? "";
    if (_trackList.indexWhere((item) => item.uiId == id) == -1) {
      _trackList.add(data);
    }
  }

  updateTopRoute(String route) {
    _topRoute = route;
    if (_topRoute == "") _topRoute = "/";
  }

  void removeTrackData() {
    _trackList.clear();
  }
}
