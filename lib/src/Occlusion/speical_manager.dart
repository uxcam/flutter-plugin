// manager.dart
import 'dart:isolate';
import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/Occlusion/occlusion_data.dart';

// Represents the data for a single special widget, including its key and visible bounds.
class SpecialWidgetData {
  final Key key;
  final Rect bounds;
  const SpecialWidgetData({required this.key, required this.bounds});

  OccludePoint toOccludePoint() {
    return OccludePoint(
      bounds.left.toNative,
      bounds.top.toNative,  
      bounds.right.toNative,
      bounds.bottom.toNative,
    );
  }
}

// Data model for communication with the Isolate.
class BoundsCalculationData {
  final Map<Key, Rect> allBounds;
  final SendPort sendPort;
  BoundsCalculationData(this.allBounds, this.sendPort);
}

// Entry point for the Isolate to perform heavy computation.
void calculateVisibleBounds(BoundsCalculationData data) {
  final Map<Key, Rect> allBounds = data.allBounds;
  final Map<Key, Rect> visibleBounds = {};

  allBounds.forEach((key, bounds) {
    bool isOccluded = false;
    for (var otherBounds in allBounds.values) {
      if (otherBounds != bounds && otherBounds.overlaps(bounds)) {
        isOccluded = true;
        break;
      }
    }
    if (!isOccluded) {
      visibleBounds[key] = bounds;
    }
  });
  data.sendPort.send(visibleBounds);
}

// The manager class to coordinate widgets and expose data.
class SpecialWidgetManager extends ChangeNotifier {
  static final SpecialWidgetManager _instance = SpecialWidgetManager._internal();
  factory SpecialWidgetManager() => _instance;
  SpecialWidgetManager._internal();

  final Set<Key> _widgetKeys = {};
  final Set<GlobalKey> _globalWidgetKeys = {};
  final Set<Key> _currentlyVisibleKeys = {};
  List<SpecialWidgetData> _latestVisibleBounds = [];
  bool _isProcessing = false;

  List<SpecialWidgetData> get latestVisibleBounds => _latestVisibleBounds;

  void registerWidget(Key key, GlobalKey globalKey) {
    _widgetKeys.add(key);
    _globalWidgetKeys.add(globalKey);
  }

  void unregisterWidget(GlobalKey key) {
    _widgetKeys.remove(key);
    _globalWidgetKeys.remove(key);
    _globalWidgetKeys.remove(key);
    _currentlyVisibleKeys.remove(key);
    _processFrame();
  }

  void onVisibilityChanged(GlobalKey key, bool isVisible) {
    if (isVisible) {
      _globalWidgetKeys.add(key);
      _currentlyVisibleKeys.add(key);
    } else {
      _globalWidgetKeys.remove(key);
      _currentlyVisibleKeys.remove(key);
    }
    _processFrame();
  }

  void _processFrame() async {
    if (_isProcessing) return;
    _isProcessing = true;

    final Map<Key, Rect> visibleWidgetBounds = {};
    for (var key in _globalWidgetKeys) {
      final GlobalKey? globalKey = key;
      if (globalKey == null) continue;

      final RenderBox? renderBox = globalKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.attached) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        visibleWidgetBounds[key] = position & size;
      }
    }

    if (visibleWidgetBounds.isEmpty) {
      _latestVisibleBounds = [];
      notifyListeners();
      _isProcessing = false;
      return;
    }

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(
      calculateVisibleBounds,
      BoundsCalculationData(visibleWidgetBounds, receivePort.sendPort),
    );

    receivePort.listen((message) {
      if (message is Map<Key, Rect>) {
        final visibleBounds = message;
        _latestVisibleBounds = visibleBounds.entries
            .map((e) => SpecialWidgetData(key: e.key, bounds: e.value))
            .toList();
        notifyListeners();
        _isProcessing = false;
      }
    });
  }
}
