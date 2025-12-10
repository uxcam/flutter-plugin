# OccludeWrapper Architecture Redesign

## Table of Contents
- [Current Architecture Problems](#current-architecture-problems)
- [Proposed Architecture](#proposed-architecture)
- [Implementation Details](#implementation-details)
- [Native Side Changes](#native-side-changes)
- [Comparison](#comparison)

---

## Current Architecture Problems

### 1. Polling-Based Updates (Inefficient)

```dart
// Current: Timer polling every 60ms regardless of changes
Timer.periodic(Duration(milliseconds: 60), (_) => _sendRectsToNative());
```

**Issues:**
- Wastes CPU cycles when widgets aren't moving
- Can miss rapid changes between polling intervals
- Not synchronized with actual frame rendering
- Continuous timer overhead even when app is idle

### 2. Dual Platform Implementations

**Files:**
- `lib/src/widgets/occlude_wrapper_ios.dart`
- `lib/src/widgets/occlude_wrapper_android.dart`

**Issues:**
- Two separate widgets with different logic
- Android has more sophisticated route detection than iOS
- Double maintenance burden
- Inconsistent behavior across platforms
- Bug fixes need to be applied twice

### 3. GlobalKey + globalPaintBounds Limitations

```dart
final bounds = _widgetKey.globalPaintBounds;
```

**Issues:**
- Doesn't account for transforms (scale, rotation, 3D perspective)
- Can return stale values during animations
- Doesn't work correctly with slivers during overscroll
- No handling of ancestor clips (viewport, ClipRect)

### 4. Third-Party Dependency

- Uses `visibility_detector` package for visibility tracking
- Adds overhead with its own internal polling mechanism
- External dependency risk

### 5. Frame Synchronization Issues

**Issues:**
- Updates sent asynchronously, not tied to actual frame rendering
- Native SDK might apply occlusion to wrong frame during animations
- Race conditions between Flutter rendering and native occlusion

### 6. Coordinate System Issues

**Issues:**
- Coordinates in logical pixels, native may expect physical pixels
- No handling of multi-view scenarios
- No devicePixelRatio consideration

### 7. Route Detection Inconsistency

**iOS:**
```dart
bool _isWidgetInTopRoute() {
  ModalRoute? modalRoute = ModalRoute.of(context);
  return modalRoute != null && modalRoute.isCurrent && modalRoute.isActive;
}
```

**Android (more sophisticated):**
```dart
bool _isWidgetInTopRoute() {
  final topRoute = _peekTopRoute(context);
  if (topRoute is PopupRoute && topRoute.opaque == false) {
    return true; // Keep occluding with dialog open
  }
  return false;
}
```

---

## Proposed Architecture

### Design Principles

1. **Hook into Flutter's Rendering Pipeline** - Use custom `RenderObject` for frame-accurate bounds
2. **Dirty Tracking** - Only send updates when bounds actually change
3. **Single Unified Implementation** - One widget, abstracted platform channel
4. **Frame-Synchronized Updates** - Use `SchedulerBinding.addPostFrameCallback`
5. **Transform-Aware** - Properly handle all transformations in the layer tree
6. **Clip-Aware** - Intersect with ancestor clips for accurate visible bounds

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    OccludeWrapper                       │
│              (Single StatefulWidget)                    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              OccludeRenderProxyBox                      │
│    (Custom RenderObject - hooks into paint pipeline)   │
│                                                         │
│  • Calculates bounds during layout/paint               │
│  • Tracks dirty state (bounds changed?)                │
│  • Reports to OcclusionRegistry after frame            │
│  • Handles ancestor clips                              │
│  • Snaps to device pixels                              │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  OcclusionRegistry                      │
│           (Singleton - manages all wrappers)           │
│                                                         │
│  • Collects all dirty rects after frame                │
│  • Batches updates to native (single channel call)     │
│  • Handles lifecycle (app pause/resume)                │
│  • Frame callback scheduling                           │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              OcclusionPlatformChannel                   │
│         (Unified abstraction for both platforms)       │
│                                                         │
│  • Single BasicMessageChannel                          │
│  • Binary protocol for efficiency                      │
│  • Physical pixel coordinates                          │
│  • Multi-view support                                  │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
     ┌─────────────┐           ┌─────────────┐
     │   iOS SDK   │           │ Android SDK │
     └─────────────┘           └─────────────┘
```

---

## Implementation Details

### 1. OccludeWrapper Widget (Unified Entry Point)

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum OcclusionType { overlay, blur, none }

class OccludeWrapper extends SingleChildRenderObjectWidget {
  final bool enabled;
  final OcclusionType type;

  const OccludeWrapper({
    super.key,
    required super.child,
    this.enabled = true,
    this.type = OcclusionType.overlay,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return OccludeRenderBox(
      enabled: enabled,
      type: type,
      registry: OcclusionRegistry.instance,
    )..updateContext(context);
  }

  @override
  void updateRenderObject(BuildContext context, OccludeRenderBox renderObject) {
    renderObject
      ..updateContext(context)
      ..enabled = enabled
      ..type = type;
  }
}
```

**Why `SingleChildRenderObjectWidget`?**
- Direct access to the rendering pipeline
- No extra Container/wrapper overhead
- Proper lifecycle hooks (attach/detach)
- Automatic cleanup on disposal

---

### 2. OccludeRenderBox (Core Implementation)

```dart
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class OccludeRenderBox extends RenderProxyBox {
  OccludeRenderBox({
    required bool enabled,
    required OcclusionType type,
    required this.registry,
  })  : _enabled = enabled,
        _type = type;

  final OcclusionRegistry registry;

  // Stable ID that survives widget rebuilds
  late final int _stableId = _generateStableId();
  static int _idCounter = 0;
  static int _generateStableId() {
    return Object.hash(++_idCounter, DateTime.now().microsecondsSinceEpoch);
  }

  int get stableId => _stableId;

  // Context reference for View.maybeOf and Scrollable.maybeOf
  BuildContext? _context;

  // State tracking
  Rect? _lastReportedBounds;
  bool _enabled;
  OcclusionType _type;

  // Scroll awareness
  ScrollPosition? _trackedScrollPosition;
  bool _isScrolling = false;

  // --- Property Setters with markNeedsPaint ---

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _markOcclusionDirty();
    markNeedsPaint();
  }

  OcclusionType get type => _type;
  set type(OcclusionType value) {
    if (_type == value) return;
    _type = value;
    _markOcclusionDirty();
    markNeedsPaint();
  }

  void _markOcclusionDirty() {
    if (!attached) return;

    if (!_enabled && _lastReportedBounds != null) {
      // Occlusion disabled - notify removal
      _lastReportedBounds = null;
      registry.markDirty(this);
    } else if (_enabled) {
      registry.markDirty(this);
    }
  }

  // --- Context and Scroll Setup ---

  void updateContext(BuildContext context) {
    _context = context;
    _setupScrollListener(context);
  }

  void _setupScrollListener(BuildContext context) {
    _detachFromScrollable();

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _trackedScrollPosition = scrollable.position;
      _trackedScrollPosition!.isScrollingNotifier.addListener(_onScrollStateChanged);
    }
  }

  void _detachFromScrollable() {
    _trackedScrollPosition?.isScrollingNotifier.removeListener(_onScrollStateChanged);
    _trackedScrollPosition = null;
  }

  void _onScrollStateChanged() {
    final wasScrolling = _isScrolling;
    _isScrolling = _trackedScrollPosition?.isScrollingNotifier.value ?? false;

    if (wasScrolling && !_isScrolling) {
      // Scroll stopped - force full precision recalculation
      markNeedsPaint();
    }
  }

  // --- Lifecycle ---

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    registry.register(this);
  }

  @override
  void detach() {
    _detachFromScrollable();
    registry.unregister(this);
    super.detach();
  }

  // --- Paint and Bounds Calculation ---

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);

    if (_isScrolling) {
      // During active scroll, throttle updates (only if moved significantly)
      _calculateAndReportBoundsThrottled(threshold: 50.0);
    } else {
      // Not scrolling - full precision update
      _calculateAndReportBounds();
    }
  }

  void _calculateAndReportBounds() {
    if (!_enabled || !attached) {
      if (_lastReportedBounds != null) {
        _lastReportedBounds = null;
        registry.markDirty(this);
      }
      return;
    }

    // Get transform to screen coordinates (handles ALL transforms)
    final transform = getTransformTo(null);
    final rawBounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    // Calculate effective clip from ancestors
    final effectiveClip = _calculateEffectiveClip();

    // Intersect bounds with clip
    Rect? clippedBounds;
    if (effectiveClip != null) {
      final intersection = rawBounds.intersect(effectiveClip);
      if (intersection.width > 0 && intersection.height > 0) {
        clippedBounds = intersection;
      }
    } else {
      clippedBounds = rawBounds;
    }

    // Snap to device pixels to eliminate float jitter
    final devicePixelRatio = _getDevicePixelRatio();
    final snappedBounds = clippedBounds != null
        ? _snapToDevicePixels(clippedBounds, devicePixelRatio)
        : null;

    // Compare with tolerance
    if (!_rectsEqualWithinTolerance(_lastReportedBounds, snappedBounds)) {
      _lastReportedBounds = snappedBounds;
      registry.markDirty(this);
    }
  }

  void _calculateAndReportBoundsThrottled({required double threshold}) {
    if (!_enabled || !attached) {
      if (_lastReportedBounds != null) {
        _lastReportedBounds = null;
        registry.markDirty(this);
      }
      return;
    }

    final transform = getTransformTo(null);
    final rawBounds = MatrixUtils.transformRect(transform, Offset.zero & size);

    // Only report if moved significantly
    if (_lastReportedBounds == null ||
        !_rectsWithinThreshold(_lastReportedBounds!, rawBounds, threshold)) {

      final effectiveClip = _calculateEffectiveClip();
      Rect? clippedBounds;
      if (effectiveClip != null) {
        final intersection = rawBounds.intersect(effectiveClip);
        if (intersection.width > 0 && intersection.height > 0) {
          clippedBounds = intersection;
        }
      } else {
        clippedBounds = rawBounds;
      }

      if (clippedBounds != null) {
        final dpr = _getDevicePixelRatio();
        _lastReportedBounds = _snapToDevicePixels(clippedBounds, dpr);
        registry.markDirty(this);
      }
    }
  }

  // --- Clip Calculation ---

  Rect? _calculateEffectiveClip() {
    Rect? clip;

    RenderObject? current = parent;
    while (current != null) {
      if (current is RenderClipRect ||
          current is RenderClipRRect ||
          current is RenderClipPath ||
          current is RenderViewport ||
          current is RenderAbstractViewport) {
        clip = _intersectClip(clip, current as RenderBox);
      }
      current = current.parent;
    }

    return clip;
  }

  Rect? _intersectClip(Rect? existing, RenderBox clipper) {
    final clipperTransform = clipper.getTransformTo(null);
    final clipperBounds = MatrixUtils.transformRect(
      clipperTransform,
      Offset.zero & clipper.size,
    );

    if (existing == null) {
      return clipperBounds;
    }
    return existing.intersect(clipperBounds);
  }

  // --- Utility Methods ---

  double _getDevicePixelRatio() {
    if (_context != null) {
      final view = View.maybeOf(_context!);
      if (view != null) return view.devicePixelRatio;
    }
    return WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  }

  int _getViewId() {
    if (_context != null) {
      final view = View.maybeOf(_context!);
      if (view != null) return view.viewId;
    }
    return 0;
  }

  Rect _snapToDevicePixels(Rect rect, double devicePixelRatio) {
    return Rect.fromLTRB(
      (rect.left * devicePixelRatio).roundToDouble() / devicePixelRatio,
      (rect.top * devicePixelRatio).roundToDouble() / devicePixelRatio,
      (rect.right * devicePixelRatio).roundToDouble() / devicePixelRatio,
      (rect.bottom * devicePixelRatio).roundToDouble() / devicePixelRatio,
    );
  }

  bool _rectsEqualWithinTolerance(Rect? a, Rect? b, [double tolerance = 0.5]) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() < tolerance &&
        (a.top - b.top).abs() < tolerance &&
        (a.right - b.right).abs() < tolerance &&
        (a.bottom - b.bottom).abs() < tolerance;
  }

  bool _rectsWithinThreshold(Rect a, Rect b, double threshold) {
    return (a.left - b.left).abs() < threshold &&
        (a.top - b.top).abs() < threshold;
  }

  // --- Getters for Registry ---

  Rect? get currentBounds => _lastReportedBounds;
  OcclusionType get currentType => _type;
  double get devicePixelRatio => _getDevicePixelRatio();
  int get viewId => _getViewId();
}
```

---

### 3. OcclusionRegistry (Batched, Frame-Synchronized)

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class OcclusionUpdate {
  final int id;
  final Rect? bounds; // null means removal
  final OcclusionType type;
  final double devicePixelRatio;
  final int viewId;

  OcclusionUpdate({
    required this.id,
    required this.bounds,
    required this.type,
    required this.devicePixelRatio,
    required this.viewId,
  });
}

class OcclusionRegistry with WidgetsBindingObserver {
  static final instance = OcclusionRegistry._();
  OcclusionRegistry._() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _registered = <OccludeRenderBox>{};
  final _dirty = <OccludeRenderBox>{};
  bool _frameCallbackScheduled = false;

  final _channel = OcclusionPlatformChannel();

  // --- Registration ---

  void register(OccludeRenderBox box) {
    _registered.add(box);
    _dirty.add(box);
    _scheduleUpdate();
  }

  void unregister(OccludeRenderBox box) {
    _registered.remove(box);
    _dirty.remove(box);
    // Notify native to remove this occlusion
    _channel.sendRemoval(box.stableId, box.viewId);
  }

  void markDirty(OccludeRenderBox box) {
    if (!_registered.contains(box)) return;
    _dirty.add(box);
    _scheduleUpdate();
  }

  // --- Frame Scheduling ---

  void _scheduleUpdate() {
    if (_frameCallbackScheduled) return;
    _frameCallbackScheduled = true;

    // Schedule AFTER the frame is painted
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameCallbackScheduled = false;
      _flushUpdates();
    });
  }

  void _flushUpdates() {
    if (_dirty.isEmpty) return;

    final updates = <OcclusionUpdate>[];

    for (final box in _dirty) {
      final bounds = box.currentBounds;

      updates.add(OcclusionUpdate(
        id: box.stableId,
        bounds: bounds,
        type: box.currentType,
        devicePixelRatio: box.devicePixelRatio,
        viewId: box.viewId,
      ));
    }
    _dirty.clear();

    // Single batched call to native
    _channel.sendBatchUpdate(updates);
  }

  // --- App Lifecycle ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Clear all occlusions when app backgrounds
      _channel.clearAll();
    } else if (state == AppLifecycleState.resumed) {
      // Re-report all registered occlusions
      for (final box in _registered) {
        _dirty.add(box);
      }
      _scheduleUpdate();
    }
  }

  // --- Debug Utilities ---

  static bool debugShowOcclusions = false;

  void debugPrintState() {
    print('OcclusionRegistry: ${_registered.length} registered, ${_dirty.length} dirty');
    for (final box in _registered) {
      print('  - ${box.stableId}: ${box.currentBounds}');
    }
  }
}
```

---

### 4. OcclusionPlatformChannel (Efficient Binary Protocol)

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

class OcclusionPlatformChannel {
  final _channel = const BasicMessageChannel<ByteData>(
    'uxcam_occlusion_v2',
    BinaryCodec(),
  );

  /// Send batched occlusion updates to native
  ///
  /// Binary format:
  /// Header: [count:4 bytes]
  /// Per item: [viewId:4][id:4][left:4][top:4][right:4][bottom:4][type:1] = 25 bytes
  void sendBatchUpdate(List<OcclusionUpdate> updates) {
    if (updates.isEmpty) return;

    const headerSize = 4;
    const itemSize = 25;

    final buffer = ByteData(headerSize + updates.length * itemSize);
    var offset = 0;

    // Header: count
    buffer.setInt32(offset, updates.length, Endian.little);
    offset += 4;

    // Items
    for (final update in updates) {
      buffer.setInt32(offset, update.viewId, Endian.little);
      offset += 4;

      buffer.setInt32(offset, update.id, Endian.little);
      offset += 4;

      if (update.bounds != null) {
        final b = update.bounds!;
        final dpr = update.devicePixelRatio;

        // Convert to physical pixels
        buffer.setFloat32(offset, b.left * dpr, Endian.little);
        buffer.setFloat32(offset + 4, b.top * dpr, Endian.little);
        buffer.setFloat32(offset + 8, b.right * dpr, Endian.little);
        buffer.setFloat32(offset + 12, b.bottom * dpr, Endian.little);
        buffer.setUint8(offset + 16, update.type.index);
      } else {
        // Removal marker: -1 for left
        buffer.setFloat32(offset, -1.0, Endian.little);
        buffer.setFloat32(offset + 4, 0, Endian.little);
        buffer.setFloat32(offset + 8, 0, Endian.little);
        buffer.setFloat32(offset + 12, 0, Endian.little);
        buffer.setUint8(offset + 16, 0);
      }
      offset += 17;
    }

    _channel.send(buffer);
  }

  /// Send removal for a single occlusion
  void sendRemoval(int id, int viewId) {
    const headerSize = 4;
    const itemSize = 25;

    final buffer = ByteData(headerSize + itemSize);
    var offset = 0;

    buffer.setInt32(offset, 1, Endian.little); // count = 1
    offset += 4;

    buffer.setInt32(offset, viewId, Endian.little);
    offset += 4;

    buffer.setInt32(offset, id, Endian.little);
    offset += 4;

    buffer.setFloat32(offset, -1.0, Endian.little); // removal marker
    offset += 17;

    _channel.send(buffer);
  }

  /// Clear all occlusions (e.g., on app background)
  void clearAll() {
    // Send empty update with special marker
    final buffer = ByteData(4);
    buffer.setInt32(0, -1, Endian.little); // -1 count = clear all
    _channel.send(buffer);
  }
}
```

---

## Native Side Changes

### Android (Kotlin)

```kotlin
// FlutterUxcamPlugin.kt

class OcclusionHandler(private val delegate: UXCamOcclusionDelegate) {
    private val activeOcclusions = mutableMapOf<Int, OcclusionRect>()

    data class OcclusionRect(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float,
        val type: Int
    )

    fun handleBinaryMessage(message: ByteBuffer) {
        message.order(ByteOrder.LITTLE_ENDIAN)

        val count = message.getInt()

        if (count == -1) {
            // Clear all
            activeOcclusions.clear()
            delegate.setOcclusionRects(emptyList())
            return
        }

        repeat(count) {
            val viewId = message.getInt()
            val id = message.getInt()
            val left = message.getFloat()
            val top = message.getFloat()
            val right = message.getFloat()
            val bottom = message.getFloat()
            val type = message.get().toInt()

            if (left < 0) {
                // Removal
                activeOcclusions.remove(id)
            } else {
                activeOcclusions[id] = OcclusionRect(left, top, right, bottom, type)
            }
        }

        // Apply to native SDK
        val rects = activeOcclusions.values.map { rect ->
            Rect(rect.left.toInt(), rect.top.toInt(), rect.right.toInt(), rect.bottom.toInt())
        }
        delegate.setOcclusionRects(rects)
    }
}
```

### iOS (Swift)

```swift
// FlutterUxcamPlugin.swift

class OcclusionHandler {
    private var activeOcclusions: [Int: OcclusionRect] = [:]

    struct OcclusionRect {
        let left: CGFloat
        let top: CGFloat
        let right: CGFloat
        let bottom: CGFloat
        let type: Int
    }

    func handleBinaryMessage(_ data: Data) {
        var offset = 0

        let count: Int32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
        offset += 4

        if count == -1 {
            // Clear all
            activeOcclusions.removeAll()
            UXCam.setOcclusionRects([])
            return
        }

        for _ in 0..<count {
            let viewId: Int32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
            offset += 4

            let id: Int32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
            offset += 4

            let left: Float32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float32.self) }
            let top: Float32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: Float32.self) }
            let right: Float32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: Float32.self) }
            let bottom: Float32 = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 12, as: Float32.self) }
            let type: UInt8 = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 16, as: UInt8.self) }
            offset += 17

            if left < 0 {
                // Removal
                activeOcclusions.removeValue(forKey: Int(id))
            } else {
                activeOcclusions[Int(id)] = OcclusionRect(
                    left: CGFloat(left),
                    top: CGFloat(top),
                    right: CGFloat(right),
                    bottom: CGFloat(bottom),
                    type: Int(type)
                )
            }
        }

        // Apply to native SDK
        let rects = activeOcclusions.values.map { rect in
            CGRect(x: rect.left, y: rect.top, width: rect.right - rect.left, height: rect.bottom - rect.top)
        }
        UXCam.setOcclusionRects(rects)
    }
}
```

---

## Comparison

| Aspect | Current Architecture | Proposed Architecture |
|--------|---------------------|----------------------|
| **Update Trigger** | Timer polling (60ms) | Frame callback (on-demand) |
| **Updates Sent** | Every 60ms even if unchanged | Only when bounds change |
| **Transform Handling** | `globalPaintBounds` (incomplete) | `getTransformTo(null)` (full matrix) |
| **Clip Handling** | None | Intersects with ancestor clips |
| **Batching** | Per-widget updates | Single batched update per frame |
| **Frame Sync** | Async, can lag behind | Post-frame callback, always accurate |
| **Route Detection** | Manual, platform-specific | Automatic via attach/detach lifecycle |
| **Memory** | Timer + VisibilityDetector overhead | Minimal, no extra widgets |
| **Platform Code** | Two separate implementations | Single unified interface |
| **Scrolling Performance** | Can miss frames, CPU overhead | Efficient, frame-aligned, throttled |
| **Animation Support** | Bounds can be stale | Always accurate after paint |
| **Coordinate System** | Logical pixels | Physical pixels with multi-view support |
| **Dependencies** | visibility_detector package | None (pure Flutter) |
| **Float Jitter** | Not handled | Snapped to device pixels |
| **Property Changes** | May not trigger updates | Forces repaint via markNeedsPaint |

---

## Migration Path

### Phase 1: Add New Implementation
1. Create new files alongside existing implementation
2. Add feature flag to switch between old/new

### Phase 2: Testing
1. Test with various scenarios (scroll, animation, transforms, clips)
2. Verify physical pixel coordinates match expectations
3. Test app lifecycle (background/foreground)

### Phase 3: Deprecate Old Implementation
1. Mark old classes as deprecated
2. Update documentation
3. Remove old files in next major version

---

## Files to Modify/Create

### New Files
- `lib/src/widgets/occlude_wrapper_v2.dart` - Unified widget
- `lib/src/widgets/occlude_render_box.dart` - Custom RenderObject
- `lib/src/widgets/occlusion_registry.dart` - Singleton manager
- `lib/src/widgets/occlusion_platform_channel.dart` - Binary protocol

### Modified Files
- `lib/flutter_uxcam.dart` - Export new widget
- `android/src/main/java/com/uxcam/flutteruxcam/FlutterUxcamPlugin.java` - Add binary handler
- `ios/Classes/FlutterUxcamPlugin.m` - Add binary handler

### Deprecated Files (to remove in future)
- `lib/src/widgets/occlude_wrapper.dart`
- `lib/src/widgets/occlude_wrapper_ios.dart`
- `lib/src/widgets/occlude_wrapper_android.dart`
- `lib/src/widgets/occlude_wrapper_manager.dart`
