import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/web/js_bridge.dart';
import 'package:flutter_uxcam/src/web/snapshot.dart';
import 'package:flutter_uxcam/src/web/web_tree_walker.dart';
import 'package:web/web.dart' as web;

/// Walks the Flutter render tree and injects a DOM snapshot
/// that the UXCam Web SDK captures via MutationObserver.
class FlutterWebRegistry {
  FlutterWebRegistry._();

  static final FlutterWebRegistry instance = FlutterWebRegistry._();

  Timer? _rescanTimer;     
  bool _isListening = false;
  int _lastSnapshotHash = 0;
  web.HTMLElement? _container;

  void start() {
      if (_isListening) return;
      _isListening = true;

      _rescanTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _collectAndPush(),
      );
    }

  void _collectAndPush() {
      try {
        final snapshots = <Snapshot>[];
        final rootElement = WidgetsBinding.instance.rootElement;
        if (rootElement != null) {
          WebTreeWalker.instance.walk(rootElement, snapshots);
        }

        final hash = Object.hashAll([
          ...snapshots.map((s) => Object.hash(s.text, (s.left / 10).round(), (s.top / 10).round(),s.color?.value ?? 0,
            s.fontColor?.value ?? 0,)),
        ]);
        if (hash == _lastSnapshotHash) return;
        _lastSnapshotHash = hash;

        _injectDom(snapshots);
      } catch (e, st) {
        consoleLog('[UXCam-Flutter] ERROR: $e\n$st'.toJS);
      }
    }

  /// Inject text snapshots as DOM elements
  
void _injectDom(List<Snapshot> snapshots) {
    var container = _container;
    if (container == null) {
      container = web.document.createElement('div') as web.HTMLElement;
      container.id = 'uxcam-render-snapshot';
      container.style.setProperty('position', 'absolute');
      container.style.setProperty('top', '0');
      container.style.setProperty('left', '0');
      container.style.setProperty('width', '100%');
      container.style.setProperty('height', '100%');
      container.style.setProperty('pointer-events', 'none');
      container.style.setProperty('overflow', 'hidden');
      container.style.setProperty('z-index', '-1');
      web.document.body?.appendChild(container);
      _container = container;
    }

    // Build a map of existing elements keyed by data-key
    final existingByKey = <String, web.HTMLElement>{};
    final toRemove = <web.HTMLElement>[];
    for (var i = 0; i < container.children.length; i++) {
      final child = container.children.item(i)! as web.HTMLElement;
      final key = child.getAttribute('data-key') ?? '';
      if (key.isNotEmpty) {
        existingByKey[key] = child;
      } else {
        toRemove.add(child);
      }
    }

    final usedKeys = <String>{};
    final keyCounter = <String, int>{};

    for (final snap in snapshots) {
      // Generate a stable key based on content identity, not position
      final baseKey = _snapshotKey(snap); 
      final count = keyCounter[baseKey] ?? 0;   
      keyCounter[baseKey] = count + 1; 
      final key = '${baseKey}_$count';

      web.HTMLElement? el = existingByKey[key];
      final isNew = el == null;

      if (isNew) {
        el = web.document.createElement(
          snap.type == SnapType.text ? 'span' : 'div',
        ) as web.HTMLElement;
        el.setAttribute('data-key', key);
        container.appendChild(el);
      }

      usedKeys.add(key);

      // Update position and size (style-only, no childList mutations)
      el.style.setProperty('position', 'absolute');
      el.style.setProperty('left', '${snap.left.toStringAsFixed(1)}px');
      el.style.setProperty('top', '${snap.top.toStringAsFixed(1)}px');
      el.style.setProperty('width', '${snap.width.toStringAsFixed(1)}px');
      el.style.setProperty('height', '${snap.height.toStringAsFixed(1)}px');
      el.style.setProperty('z-index', '${snap.order}');

      if (snap.type == SnapType.box) {
        if ((el.textContent ?? '').isNotEmpty) {
          el.textContent = '';
        }

        if (snap.color != null) {
          final c = snap.color!;
          el.style.setProperty('background-color',
              'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
        } else {
          el.style.removeProperty('background-color');
        }

        if (snap.borderRadius != null) {
          final br = snap.borderRadius!.resolve(TextDirection.ltr);
          el.style.setProperty('border-radius',
              '${br.topLeft.x.toStringAsFixed(1)}px '
              '${br.topRight.x.toStringAsFixed(1)}px '
              '${br.bottomRight.x.toStringAsFixed(1)}px '
              '${br.bottomLeft.x.toStringAsFixed(1)}px');
        } else {
          el.style.removeProperty('border-radius');
        }

        if (snap.border != null && snap.border is Border) {
          final b = snap.border! as Border;
          _applyBorderSide(el, 'top', b.top);
          _applyBorderSide(el, 'right', b.right);
          _applyBorderSide(el, 'bottom', b.bottom);
          _applyBorderSide(el, 'left', b.left);
        } else {
          el.style.removeProperty('border-top');
          el.style.removeProperty('border-right');
          el.style.removeProperty('border-bottom');
          el.style.removeProperty('border-left');
        }

        if (snap.imageUrl != null) {
          var img = el.querySelector('img') as web.HTMLImageElement?;
          if (img == null) {
            img = web.document.createElement('img') as web.HTMLImageElement;
            img.style.setProperty('width', '100%');
            img.style.setProperty('height', '100%');
            img.style.setProperty('object-fit', 'cover');
            img.style.setProperty('pointer-events', 'none');
            el.appendChild(img);
          }
          if (img.getAttribute('src') != snap.imageUrl!) {
            img.src = snap.imageUrl!;
          }
        } else {
          final existingImg = el.querySelector('img');
          existingImg?.remove();
        }
      } else {
        // Text element
        if (el.textContent != snap.text) {
          el.textContent = snap.text;
        }
        el.style.setProperty('font-size', '${snap.fontSize.toStringAsFixed(1)}px');
        el.style.setProperty('overflow', 'hidden');

        final isMultiLine = snap.height > snap.fontSize * 1.8;
        if (isMultiLine) {
          el.style.setProperty('white-space', 'normal');
          el.style.setProperty('line-height',
              '${(snap.fontSize * 1.4).toStringAsFixed(1)}px');
        } else {
          el.style.setProperty('white-space', 'nowrap');
          el.style.setProperty('line-height',
              '${snap.height.toStringAsFixed(1)}px');
        }

        if (snap.fontColor != null) {
          final c = snap.fontColor!;
          el.style.setProperty('color',
              'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
        } else {
          el.style.removeProperty('color');
        }

        if (snap.fontWeight != null && snap.fontWeight != FontWeight.normal) {
          el.style.setProperty('font-weight', '${snap.fontWeight!.value}');
        } else {
          el.style.removeProperty('font-weight');
        }
      }
    }

    // Remove elements whose keys are no longer in the snapshot list
    for (final entry in existingByKey.entries) {
      if (!usedKeys.contains(entry.key)) {
        entry.value.remove();
      }
    }
    for (final el in toRemove) {
      el.remove();
    }
  }

  /// Generate a stable identity key for a snapshot based on its content,
  /// not its position. This ensures the same logical element always maps
  /// to the same DOM node.
  String _snapshotKey(Snapshot snap) {
    if (snap.type == SnapType.text) {
      return 'txt_${snap.text.hashCode}_${snap.fontSize.round()}';
    }
    if (snap.imageUrl != null) {
      return 'img_${snap.imageUrl.hashCode}';
    }
    // Box identity = just "box" — uniqueness comes from the keyCounter
    return 'box';
  }

  void _applyBorderSide(web.HTMLElement el, String side, BorderSide bs) {
    if (bs.width > 0 && bs.style != BorderStyle.none) {
      final c = bs.color;
      el.style.setProperty('border-$side',
          '${bs.width.toStringAsFixed(1)}px solid '
          // ignore: deprecated_member_use
          'rgba(${c.red},${c.green},${c.blue},${c.opacity.toStringAsFixed(2)})');
    }
  }

  void dispose() {
    _rescanTimer?.cancel();
    _rescanTimer = null;
    _lastSnapshotHash = 0; 
    _container?.remove();
    _container = null;
    _isListening = false;
  }
}