// special_widget_wrapper.dart
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'speical_manager.dart';

class SpecialWidget extends StatefulWidget {
  final Widget child;
  final Key? key;

  const SpecialWidget({this.key, required this.child}) : super(key: key);

  @override
  _SpecialWidgetState createState() => _SpecialWidgetState();
}

class _SpecialWidgetState extends State<SpecialWidget> {
  late final Key _internalKey;
  final GlobalKey _globalKey = GlobalKey();
  final _manager = SpecialWidgetManager();

  @override
  void initState() {
    super.initState();
    _internalKey = widget.key ?? UniqueKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _manager.registerWidget(_internalKey, _globalKey);
    });
  }

  @override
  void dispose() {
    _manager.unregisterWidget(_globalKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _globalKey,
      onVisibilityChanged: (info) {
        _manager.onVisibilityChanged(_globalKey, info.visibleFraction > 0);
      },
      child: RepaintBoundary(
        child: widget.child,
      ),
    );
  }
}
