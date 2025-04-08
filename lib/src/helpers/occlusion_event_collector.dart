import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/helpers/occulsion_event_stream_notifier.dart';
import 'package:flutter_uxcam/src/models/occlude_data.dart';

class OcclusionEventCollector {
  static const EVENT_WINDOW_DURATION = 100; //100ms
  static final OcclusionEventCollector _instance =
      OcclusionEventCollector._internal();
  factory OcclusionEventCollector() => _instance;
  OcclusionEventCollector._internal();

  final _controller = StreamController<OccludeData>.broadcast();
  StreamController<OccludeData> get controller => _controller;

  final OcculsionEventStreamNotifier _streamNotifier =
      OcculsionEventStreamNotifier();
  OcculsionEventStreamNotifier get streamNotifier => _streamNotifier;

  void emit(OccludeData value) => _controller.add(value);

  Future<List<OccludeData>> collectOcclusionRectsFor(
      {Duration duration =
          const Duration(milliseconds: EVENT_WINDOW_DURATION)}) async {
    final events = <OccludeData>[];
    final completer = Completer<List<OccludeData>>();
    print(
        "occlude : The stream is now open ${DateTime.now().millisecondsSinceEpoch}");
    StreamSubscription<OccludeData> subscription =
        _controller.stream.listen((data) {
      events.add(data);
    });
    _streamNotifier.open();
    Future.delayed(duration, () async {
      await subscription.cancel();
      print(
          "occlude : The stream is now closed ${DateTime.now().millisecondsSinceEpoch}");
      completer.complete(events);
    });
    return completer.future;
  }
}
