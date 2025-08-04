import 'package:flutter_uxcam/flutter_uxcam.dart';

class FlutterUxAITextOcclusionKeys {
  static const recognitionLanguage = "recognitionLanguage";
}

class FlutterUxAITextOcclusion extends FlutterUXOcclusion {
  List<String> recognitionLanguages = ["en-US"];

  @override
  String get name =>
      'UXOcclusionTypeAITextOcclusion'; // not used.. 

  @override
  UXOcclusionType get type => UXOcclusionType.aiTextOcclusion;

  @override
  Map<String, dynamic>? get configuration => {
        FlutterUxAITextOcclusionKeys.recognitionLanguage: recognitionLanguages
      };

  FlutterUxAITextOcclusion(
      {List<String> recognitionLanguages = const ["en-US"],
      List<String> screens = const [],
      bool excludeMentionedScreens = false})
      : super(screens, excludeMentionedScreens) {
    this.recognitionLanguages = recognitionLanguages;
  }
}
