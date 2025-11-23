import 'dart:ui';

import 'package:flutter/foundation.dart';

class RegisteredOcclusionRectsMap<GlobalKey, Rect> extends ChangeNotifier {
  final Map<GlobalKey, Rect> _map = {};

  void add(GlobalKey key, Size size, Offset position) {
    _map[key] = (position & size) as Rect;
    notifyListeners();
  }

  void remove(GlobalKey key) {
    _map.remove(key);
    notifyListeners();
  }

  void clear() {
    _map.clear();
    notifyListeners();
  }
}
