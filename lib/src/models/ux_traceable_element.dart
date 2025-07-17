import 'package:flutter/material.dart';

const UX_UNKOWN = -1;
const UX_CUSTOM = 0;
const UX_TEXT = 7;
const UX_IMAGE = 12;
const UX_DECOR = 13;
const UX_BUTTON = 1;
const UX_FIELD = 2;
const UX_COMPOUND = 3;
const UX_VIEWGROUP = 5;

class UxTraceableElement {
  /// Static list of user defined types
  static List<Type> userDefinedTypes = [];

  /// Add a type to userDefinedTypes if not already present
  static void addUserDefinedType(Type type) {
    if (!userDefinedTypes.contains(type)) {
      userDefinedTypes.add(type);
    }
  }

  /// Remove a type from userDefinedTypes
  static void removeUserDefinedType(Type type) {
    userDefinedTypes.remove(type);
  }

  /// Set the entire userDefinedTypes list
  static void setUserDefinedTypes(List<Type> types) {
    userDefinedTypes = List<Type>.from(types);
  }

  /// Clear all userDefinedTypes
  static void clearUserDefinedTypes() {
    userDefinedTypes.clear();
  }

  List<Type> knownButtonTypes = [
    ElevatedButton,
    TextButton,
    OutlinedButton,
    GestureDetector,
    InkWell,
    IconButton,
    FloatingActionButton,
  ];

  List<Type> nonInteractiveTypes = [
    Image,
    Text,
    RichText,
    Icon,
    DecoratedBox,
  ];

  List<Type> interactiveTypes = [
    Radio,
    Slider,
    Switch,
    Checkbox,
  ];

  List<Type> fieldTypes = [
    TextField,
  ];

  List<Type> scrollingContainerTypes = [
    ListView,
    SingleChildScrollView,
    GridView,
  ];

  List<Type> containerTypes = [
    Scaffold,
    ListTile,
  ];

  List<Type> variableTypes = [
    Container,
  ];

  List<Type> overlayTypes = [
    BottomSheet,
    AlertDialog,
  ];

  bool isOverLay(Element element) {
    return overlayTypes.contains(element.widget.runtimeType);
  }

  int getUxType(Element element) {
    int _uiType = UX_UNKOWN;

    if (userDefinedTypes.contains(element.widget.runtimeType)) {
      _uiType = UX_CUSTOM;
    }
    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = UX_BUTTON;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      _uiType = UX_FIELD;
    }
    if (_isInteractive(element)) {
      _uiType = UX_COMPOUND;
    }
    if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      if (element.widget.runtimeType.toString() == "Text" ||
          element.widget.runtimeType.toString() == "RichText") {
        _uiType = UX_TEXT;
      }
      if (element.widget.runtimeType.toString() == "Image" ||
          element.widget.runtimeType.toString() == "Icon") {
        _uiType = UX_IMAGE;
      }
      if (element.widget.runtimeType.toString() == "DecoratedBox") {
        final widget = element.widget as DecoratedBox;
        if (widget.decoration is BoxDecoration) {
          if ((widget.decoration as BoxDecoration).image != null) {
            _uiType = UX_DECOR;
          }
          if ((widget.decoration as BoxDecoration).shape == BoxShape.circle) {
            _uiType = UX_DECOR;
          }
        }
        if (widget.decoration is ShapeDecoration) {
          _uiType = UX_DECOR;
        }
      }
    }

    if (containerTypes.contains(element.widget.runtimeType) ||
        scrollingContainerTypes.contains(element.widget.runtimeType) ||
        overlayTypes.contains(element.widget.runtimeType)) {
      _uiType = UX_VIEWGROUP;
    }
    return _uiType;
  }

  bool _isInteractive(Element element) {
    final isPresent = interactiveTypes.contains(element.widget.runtimeType);
    if (isPresent) {
      return true;
    } else {
      //Radio types require extra processing
      if (element.widget.runtimeType.toString().startsWith("Radio")) {
        return true;
      }
    }
    return false;
  }
}
