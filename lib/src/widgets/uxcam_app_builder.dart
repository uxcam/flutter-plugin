import 'package:flutter/widgets.dart';
import 'package:flutter_uxcam/src/helpers/app_overlay_capture_manager.dart';

/// Builder to inject an invisible overlay with a top-level RepaintBoundary
///
/// Usage: MaterialApp(builder: FlutterUxcam.appBuilder, ...)
Widget uxcamAppBuilder(BuildContext context, Widget? child) {
  final manager = AppOverlayCaptureManager();
  // Use Overlay to ensure our boundary spans dialogs, modals, etc.
  return Overlay(
    initialEntries: [
      OverlayEntry(
        maintainState: true,
        opaque: false,
        builder: (ctx) {
          return RepaintBoundary(
            key: manager.rootBoundaryKey,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ],
  );
}

