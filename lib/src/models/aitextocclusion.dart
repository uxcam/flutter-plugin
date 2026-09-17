import 'package:flutter_uxcam/src/models/flutter_occlusion.dart';

class FlutterUxAITextOcclusionKeys {
  static const recognitionLanguage = "recognitionLanguage";
  static const hideGestures = "hideGestures";
}

class FlutterUXAITextOcclusion extends FlutterUXOcclusion {
  List<String> recognitionLanguages = const ["en-US"];
  bool hideGestures = false;

  @override
  String get name => 'UXOcclusionTypeAITextOcclusion';

  @override
  UXOcclusionType get type => UXOcclusionType.aiTextOcclusion;

  @override
  Map<String, dynamic>? get configuration => {
        FlutterUxAITextOcclusionKeys.recognitionLanguage: recognitionLanguages,
        FlutterUxAITextOcclusionKeys.hideGestures: hideGestures
      };

  FlutterUXAITextOcclusion(
      {List<String> recognitionLanguages = const ["en-US"],
      bool hideGestures = false,
      List<String> screens = const [],
      bool excludeMentionedScreens = false})
      : super(screens, excludeMentionedScreens) {
    this.recognitionLanguages = recognitionLanguages;
    this.hideGestures = hideGestures;
  }
}
