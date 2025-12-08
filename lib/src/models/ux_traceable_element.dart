import 'package:flutter/material.dart';
import 'package:flutter_uxcam/src/core/uxcam_widget_classifier.dart';

// Re-export constants from UXCamWidgetClassifier for backwards compatibility
// ignore: constant_identifier_names
const UX_UNKOWN = UX_UNKNOWN;

/// Widget type classifier for legacy UXCamHandler support.
@Deprecated('Use UXCamWidgetClassifier or FlutterUxcam.registerButtonType() instead')
class UxTraceableElement {
  static Set<Type> _userDefinedTypes = {};

  @Deprecated('Use FlutterUxcam.registerButtonType() instead')
  static List<Type> get userDefinedTypes => _userDefinedTypes.toList();

  @Deprecated('Use FlutterUxcam.registerButtonType() instead')
  static void addUserDefinedType(Type type) {
    _userDefinedTypes.add(type);
    UXCamWidgetClassifier.registerButtonType(type);
  }

  @Deprecated('Use FlutterUxcam.registerButtonType() with unregisterButtonType() instead')
  static void removeUserDefinedType(Type type) {
    _userDefinedTypes.remove(type);
    UXCamWidgetClassifier.unregisterButtonType(type);
  }

  @Deprecated('Use FlutterUxcam.registerButtonType() for each type instead')
  static void setUserDefinedTypes(List<Type> types) {
    _userDefinedTypes = Set<Type>.from(types);
    UXCamWidgetClassifier.clearCustomTypes();
    for (final type in types) {
      UXCamWidgetClassifier.registerButtonType(type);
    }
  }

  @Deprecated('Use UXCamWidgetClassifier.clearCustomTypes() instead')
  static void clearUserDefinedTypes() {
    _userDefinedTypes.clear();
    UXCamWidgetClassifier.clearCustomTypes();
  }

  bool isOverLay(Element element) {
    return UXCamWidgetClassifier.isOverlayType(element.widget.runtimeType);
  }

  int getUxType(Element element) {
    final runtimeType = element.widget.runtimeType;

    if (_userDefinedTypes.contains(runtimeType)) {
      return UX_CUSTOM;
    }

    return UXCamWidgetClassifier.classifyElement(element);
  }

  static int parseStringIdToGetType(String typePath) {
    int type = UX_UNKNOWN;
    final typeHierarchyList = typePath.split("#");
    for (String typeItem in typeHierarchyList) {
      final item = int.tryParse(typeItem);
      if (item != null) {
        if (item == UX_VIEWGROUP) {
          type = UX_VIEWGROUP;
          continue;
        }
        if (item == UX_FIELD) {
          type = UX_FIELD;
          continue;
        }
        if (type == UX_FIELD || type == UX_BUTTON || type == UX_COMPOUND) {
          continue;
        }
        type = item;
      }
    }
    return type;
  }
}
