import 'package:flutter/material.dart';

typedef WidgetMatch = bool Function(Widget widget);
typedef WidgetWrap = Widget Function(Widget widget);

class ElementCapture extends InheritedWidget {
  final WidgetMatch match;
  final WidgetWrap wrap;

  const ElementCapture({
    required this.match,
    required this.wrap,
    required Widget child,
    Key? key,
  }) : super(child: child);

  static ElementCapture? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ElementCapture>();
  }

  @override
  bool updateShouldNotify(ElementCapture old) {
    return match != old.match || wrap != old.wrap;
  }
}

// widget_interceptor.dart

class WidgetInterceptor extends StatelessWidget {
  final Widget child;

  const WidgetInterceptor({Key? key, required this.child});

  @override
  Widget build(BuildContext context) {
    final provider = ElementCapture.of(context);
    if (provider == null) return child;
    return _wrapRecursively(provider.match, provider.wrap, child);
  }

  Widget _wrapRecursively(WidgetMatch match, WidgetWrap wrap, Widget widget) {
    if (widget is ElevatedButton) return wrap(widget);
    final nextWidget = _skipInternalWidget(widget);
    if (nextWidget != null) {
      _wrapRecursively(match, wrap, nextWidget);
    }

    // if (widget is SingleChildRenderObjectWidget && widget.child != null) {
    //   return _wrapContainer(
    //       widget, _wrapRecursively(match, wrap, widget.child!));
    // }

    // if (widget is MultiChildRenderObjectWidget) {
    //   final newChildren =
    //       widget.children.map((c) => _wrapRecursively(match, wrap, c)).toList();
    //   return _wrapMultiChild(widget, newChildren);
    // }

    return widget;
  }

  Widget? _skipInternalWidget(Widget widget) {
    if (widget is FocusScope) return widget.child;
    if (widget is Focus) return widget.child;
    if (widget is Semantics) return widget.child;
    if (widget is Shortcuts) return widget.child;
    if (widget is Actions) return widget.child;
    if (widget is MediaQuery) return widget.child;
    if (widget is Directionality) return widget.child;
    return null;
  }

  Widget _wrapContainer(Widget original, Widget child) {
    if (original is Container) {
      return Container(
        key: original.key,
        padding: original.padding,
        child: child,
      );
    }
    return original;
  }

  Widget _wrapMultiChild(Widget original, List<Widget> newChildren) {
    if (original is Column) {
      return Column(
        key: original.key,
        children: newChildren,
        mainAxisAlignment: original.mainAxisAlignment,
        crossAxisAlignment: original.crossAxisAlignment,
      );
    }
    if (original is Row) {
      return Row(
        key: original.key,
        children: newChildren,
        mainAxisAlignment: original.mainAxisAlignment,
        crossAxisAlignment: original.crossAxisAlignment,
      );
    }
    return original;
  }
}
