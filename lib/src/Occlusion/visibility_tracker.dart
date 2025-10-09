// visibility_tracker.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';

import 'visibility_tracer_info.dart';
import 'visibility_manager.dart';
import 'visibility_tracker_animationproxy_widget.dart';

/// Autonomous visibility tracking widget
class VisibilityTracker extends StatefulWidget {
  final String id;
  final Widget child;

  const VisibilityTracker({
    Key? key,
    required this.id,
    required this.child,
  }) : super(key: key);

  @override
  State<VisibilityTracker> createState() => VisibilityTrackerState();
}

class VisibilityTrackerState extends State<VisibilityTracker>
    with WidgetsBindingObserver, RouteAware {
  
  final GlobalKey _key = GlobalKey();
  VisibilityTrackerInfo? _lastInfo;
  RouteObserver<ModalRoute>? _routeObserver;
  ScrollPosition? _scrollPosition;
  RenderObject? _renderObject;
  
  // Internal configuration
  static const double _visibilityThreshold = 0.01; // 1% visibility threshold
  static const Duration _debounceDelay = Duration(milliseconds: 50);
  Timer? _debounceTimer;
  
  // Track various state changes
  bool _isInForeground = true;
  bool _isRouteActive = true;
  
  @override
  void initState() {
    super.initState();
    
    // Register with manager
    VisibilityManager.instance.registerWidget(widget.id, this);
    // Ensure debug overlay is installed once per app tree
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        VisibilityManager.instance.ensureDebugOverlay(context); 
      }
    });
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Schedule initial check
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializeTracking();
    });
  }

  void _initializeTracking() {
    if (!mounted) return;
    
    // Get render object
    _renderObject = _key.currentContext?.findRenderObject();
    
    // Attach to route observer
    _attachRouteObserver();
    
    // Attach scroll listener
    _attachScrollListener();
    
    // Initial visibility check
    checkVisibility();
    
  }

  void _attachRouteObserver() {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      // RouteObserver needs to be provided through Navigator or manually managed
      final route = ModalRoute.of(context);
      if (route != null && _routeObserver != null) {
        _routeObserver!.subscribe(this, route);
      }
    }
  }

  void _attachScrollListener() {
    // Find any scrollable ancestor
    void searchForScrollable(BuildContext context) {
      context.visitAncestorElements((element) {
        if (element.widget is ScrollView || element.widget is Scrollable) {
          // ignore: deprecated_member_use
            final scrollable = Scrollable.maybeOf(element);
          if (scrollable != null && scrollable.position != _scrollPosition) {
            _detachScrollListener();
            _scrollPosition = scrollable.position;
            _scrollPosition!.addListener(_onScroll);
            print('[${widget.id}] Attached to scroll listener');
          }
          return false;
        }
        return true;
      });
    }
    
    searchForScrollable(context);
  }

  void _detachScrollListener() {
    if (_scrollPosition != null) {
      _scrollPosition!.removeListener(_onScroll);
      _scrollPosition = null;
    }
  }

  void _onScroll() {
    scheduleVisibilityCheck();
  }

  void scheduleVisibilityCheck() {  
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (mounted) {
        checkVisibility();
      }
    });
  }

  void checkVisibility() {
    if (!mounted) return;

    if (!_isWidgetInTopRoute()) {
      _updateVisibility(false, 0.0, null, null, null);
      return;
    }

    if (!_isInForeground || !_isRouteActive) {
      _updateVisibility(false, 0.0, null, null, null);
      return;
    }

    final RenderObject? renderObject = _key.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) {
      _updateVisibility(false, 0.0, null, null, null);
      return;
    }

    final RenderBox renderBox = renderObject as RenderBox;
    if (!renderBox.hasSize) {
      _updateVisibility(false, 0.0, null, null, null);
      return;
    }

    // Get size and position
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: null);
    final bounds = offset & size;

    // Check if covered by modal or overlay
    if (_isCoveredByModal()) {
      _updateVisibility(false, 0.0, bounds, size, offset);
      return;
    }

    // Get viewport bounds
    final viewport = _getViewportBounds();
    
    // Calculate intersection
    final intersection = viewport.intersect(bounds);
    final bool intersects = !intersection.isEmpty;
    
    // Calculate visibility fraction
    double visibilityFraction = 0.0;
    if (intersects && size.width > 0 && size.height > 0) {
      final visibleArea = intersection.width * intersection.height;
      final totalArea = size.width * size.height;
      visibilityFraction = visibleArea / totalArea;
    }

    final isVisible = intersects && visibilityFraction >= _visibilityThreshold;
    _updateVisibility(isVisible, visibilityFraction, bounds, size, offset);
  }

  void _updateVisibility(bool isVisible, double fraction, Rect? bounds, Size? size, Offset? position) {
    final info = VisibilityTrackerInfo(
      isVisible: isVisible,
      bounds: bounds,
      visibilityFraction: fraction,
      timestamp: DateTime.now(),
      widgetSize: size,
      globalPosition: position,
    );

    VisibilityManager.instance.updateVisibility(widget.id, info);
  }

  bool _isCoveredByModal() {
    bool hasModal = false;
    
    // Check for modal barriers or overlays
    context.visitChildElements((element) {
      if (element.widget is ModalBarrier || element.widget.runtimeType.toString().contains('Overlay')) {
        hasModal = true;
      }
    });

    // Check navigation stack for modal routes
    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      // ignore: deprecated_member_use
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        hasModal = true;
      }
    }

    return hasModal;
  }

  bool _isWidgetInTopRoute() {
    if (!mounted) return false;
    try {
      ModalRoute? modalRoute = ModalRoute.of(context);
      return modalRoute != null && modalRoute.isCurrent && modalRoute.isActive;
    } on FlutterError {
      return false;
    }
  }

  Rect _getViewportBounds() {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null) {
      return Offset.zero & mediaQuery.size;
    }
    
    // Fallback to render view
    final renderView = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = renderView.physicalSize / renderView.devicePixelRatio;
    return Offset.zero & size;
  }

  // Lifecycle callbacks
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInForeground = state == AppLifecycleState.resumed;
    checkVisibility();
  }

  @override
  void didChangeMetrics() {
    // Handle orientation changes
    scheduleVisibilityCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Re-attach listeners when dependencies change
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _attachScrollListener();
      _attachRouteObserver();
      checkVisibility();
    });
  }

  // Route callbacks
  @override
  void didPush() {
    _isRouteActive = true;
    checkVisibility();
  }

  @override
  void didPopNext() {
    _isRouteActive = true;
    checkVisibility();
  }

  @override
  void didPop() {
    _isRouteActive = false;
    checkVisibility();
  }

  @override
  void didPushNext() {
    _isRouteActive = false;
    checkVisibility();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _detachScrollListener();
    
    if (_routeObserver != null) {
      _routeObserver!.unsubscribe(this);
    }
    
    WidgetsBinding.instance.removeObserver(this);
    VisibilityManager.instance.removeWidget(widget.id);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for any widget rebuilds that might affect visibility
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        checkVisibility();
      }
    });

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        scheduleVisibilityCheck();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          scheduleVisibilityCheck();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: RepaintBoundary(
            child: VisibilityTrackerAnimationProxyWidget(
              child: KeyedSubtree(
                key: _key,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



