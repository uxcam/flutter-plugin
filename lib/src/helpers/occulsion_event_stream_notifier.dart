import 'package:flutter/material.dart';

class OcculsionEventStreamNotifier extends ChangeNotifier {
  bool _isStreamOpen = false;

  void open() {
    _isStreamOpen = true;
    notifyListeners();
  }
}
