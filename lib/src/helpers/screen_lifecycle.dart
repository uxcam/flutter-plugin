import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ScreenLifecycle extends StatefulWidget {
  /// Callback on when screen is not in focus
  final VoidCallback? onFocusLost;

  /// Callback on when screen is in focus
  final VoidCallback? onFocusGained;

  // The widget to add functionality
  final Widget child;

  const ScreenLifecycle({
    Key? key,
    this.onFocusLost,
    this.onFocusGained,
    required this.child,
  });

  @override
  State<ScreenLifecycle> createState() => _ScreenLifecycleState();
}

class _ScreenLifecycleState extends State<ScreenLifecycle>
    with WidgetsBindingObserver {
  final _visibilityDetectorKey = UniqueKey();

  bool _isAppInForeground = true;
  bool _isAppInVisible = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _notifyApplicationTransition(state);
  }

  /// Checking if the app is in foreground
  void _notifyApplicationTransition(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;

    notifyToggleCallback();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityDetectorKey,
      onVisibilityChanged: (VisibilityInfo visibilityInfo) {
        final visibilityFraction = visibilityInfo.visibleFraction;
        _isAppInVisible = visibilityFraction == 0.0;
        notifyToggleCallback();
      },
      child: widget.child,
    );
  }

  void notifyToggleCallback() {
    !_isAppInVisible && _isAppInForeground && _isVisible(widget)
        ? widget.onFocusGained?.call()
        : widget.onFocusLost?.call();
  }

  bool _isVisible(Widget widget) {
    if (widget is Visibility) {
      return widget.visible;
    }
    if (widget is Opacity) {
      return widget.opacity > 0;
    }
    if (widget is Offstage) {
      return !widget.offstage;
    }
    return true;
  }
}
