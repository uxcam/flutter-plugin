import 'package:flutter/material.dart';
import 'visibility_tracker.dart';

/// Detects animations in the widget tree
class VisibilityTrackerAnimationProxyWidget extends StatefulWidget {
  final Widget child;

  const VisibilityTrackerAnimationProxyWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<VisibilityTrackerAnimationProxyWidget> createState() => VisibilityTrackerAnimationProxyWidgetState();
}

class VisibilityTrackerAnimationProxyWidgetState extends State<VisibilityTrackerAnimationProxyWidget>
    with TickerProviderStateMixin {
  
  final Set<AnimationController> _controllers = {};
  final Set<Animation> _animations = {};

  @override
  void initState() {
    super.initState();
    _detectAnimations();
  }

  void _detectAnimations() {
    // Find animation controllers in the tree
    context.visitAncestorElements((element) {
      if (element.widget is AnimatedWidget) {
        final animatedWidget = element.widget as AnimatedWidget;
        final listenable = animatedWidget.listenable;
        
        if (listenable is Animation) {
          _animations.add(listenable);
          listenable.addListener(_onAnimationChange);
        }
      }
      return true;
    });
  }

  void _onAnimationChange() {
    // Trigger visibility check in parent
    if (mounted && context.findAncestorStateOfType<VisibilityTrackerState>() != null) {
      context.findAncestorStateOfType<VisibilityTrackerState>()!.scheduleVisibilityCheck();
    }
  }

  @override
  void dispose() {
    for (final animation in _animations) {
      animation.removeListener(_onAnimationChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
