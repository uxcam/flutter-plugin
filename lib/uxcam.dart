import 'package:flutter/services.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlusion_manager.dart';

class UxCam {
  FlutterUxcamNavigatorObserver navigationObserver;
  final OcclusionEventCollector _collector = OcclusionEventCollector();

  UxCam({required this.navigationObserver}) {
    const BasicMessageChannel<String> occlusionRectsChannel =
        BasicMessageChannel<String>(
            "occlusion_rects_coordinates", StringCodec());
    occlusionRectsChannel.setMessageHandler((event) async {
      await SchedulerBinding.instance.endOfFrame;
      final collectedData = await _collector.collectOcclusionRectsFor();
      final points = _convertOccludeDataToRects(collectedData);
      return points.toString();
    });
  }

  List<Map<String, dynamic>> _convertOccludeDataToRects(
      List<OccludeData> collectedData) {
    final currentStack = navigationObserver.screenNames;
    if (currentStack.length == 1) {
      return collectedData.map((e) => e.point.toJson()).toList();
    }
    if (currentStack.isNotEmpty && currentStack.last == ":popup") {
      return [];
    } else {
      return collectedData.map((e) => e.point.toJson()).toList();
    }
  }

  Future<void> _deferToEndOfEveryFrame() async {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await SchedulerBinding.instance.endOfFrame;
    });
  }
}
