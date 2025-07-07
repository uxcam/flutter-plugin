import 'package:flutter/material.dart';

class UxTraceableElement {
  List<Type> userDefinedTypes = [];

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
  ];

  List<Type> overlayTypes = [
    BottomSheet,
    AlertDialog,
  ];

  bool isOverLay(Element element) {
    return overlayTypes.contains(element.widget.runtimeType);
  }

  int getUxType(Element element) {
    int _uiType = -1;

    if (knownButtonTypes.contains(element.widget.runtimeType)) {
      _uiType = 1;
    }
    if (fieldTypes.contains(element.widget.runtimeType)) {
      _uiType = 2;
    }
    if (_isInteractive(element)) {
      _uiType = 3;
    }
    if (nonInteractiveTypes.contains(element.widget.runtimeType)) {
      if (element.widget.runtimeType.toString() == "Text" ||
          element.widget.runtimeType.toString() == "RichText") {
        _uiType = 7;
      }
      if (element.widget.runtimeType.toString() == "Image" ||
          element.widget.runtimeType.toString() == "Icon") {
        _uiType = 12;
      }
    }

    if (containerTypes.contains(element.widget.runtimeType) ||
        scrollingContainerTypes.contains(element.widget.runtimeType) ||
        overlayTypes.contains(element.widget.runtimeType)) {
      _uiType = 5;
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
