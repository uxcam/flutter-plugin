import 'package:flutter/foundation.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper_android.dart';

class BoundsTracker extends ChangeNotifier {
  static final BoundsTracker instance = BoundsTracker._();
  BoundsTracker._();

  final List<OccludeBox> _occludedBoxes = [];

  List<OccludeBox> occludedBoxes() {
    return List.unmodifiable(_occludedBoxes.where((box) => box.isVisible));
  }

  void register(OccludeBox box) {
    _occludedBoxes.add(box);
  }

  void unRegister(OccludeBox box) {
    _occludedBoxes.remove(box);
  }
}
