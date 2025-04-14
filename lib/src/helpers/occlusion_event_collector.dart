import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/helpers/occulsion_event_stream_notifier.dart';

class OcclusionEventCollector {
  static const EVENT_WINDOW_DURATION = 5; //5ms
  static final OcclusionEventCollector _instance =
      OcclusionEventCollector._internal();
  factory OcclusionEventCollector() => _instance;
  OcclusionEventCollector._internal();

  final _controller = StreamController<GlobalKey>.broadcast();
  StreamController<GlobalKey> get controller => _controller;

  void updateKeyMapping(GlobalKey key, OccludePoint occludePoint) {
    keyRectMap[key] = occludePoint;
  }

  void emit(GlobalKey value) => _controller.add(value);

  Future<List<GlobalKey>> collectOcclusionRectsFor(
      {Duration duration =
          const Duration(milliseconds: EVENT_WINDOW_DURATION)}) async {
    final events = <GlobalKey>[];
    final completer = Completer<List<GlobalKey>>();
    print(
        "occlude : The stream is now open ${DateTime.now().millisecondsSinceEpoch}");
    StreamSubscription<GlobalKey> subscription =
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
