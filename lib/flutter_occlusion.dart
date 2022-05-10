

import 'package:flutter/cupertino.dart';

class FlutterUxOcclusionKeys {
  static const screens = "screens";
  static const name = "name";
  static const type = "type";
  static const excludeMentionedScreens = "excludeMentionedScreens";
  static const config = "config";
}

enum UXOcclusionType {
  none, occludeAllTextFields, overlay, blur, unknown
}

abstract class FlutterUXOcclusion {

  String get name;
  UXOcclusionType get type;
  List<String> screens = [];
  bool excludeMentionedScreens = false;
  Map<String, dynamic>? get configuration;

  FlutterUXOcclusion(this.screens, this.excludeMentionedScreens);

  Map<String, dynamic> toJson() {
    return {
      FlutterUxOcclusionKeys.name: name,
      FlutterUxOcclusionKeys.type: type.index,
      FlutterUxOcclusionKeys.screens: screens,
      FlutterUxOcclusionKeys.excludeMentionedScreens: excludeMentionedScreens,
      FlutterUxOcclusionKeys.config: configuration
    };
  }
}