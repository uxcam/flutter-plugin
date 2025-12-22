import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const int UX_UNKNOWN = -1;
const int UX_CUSTOM = 0;
const int UX_BUTTON = 1;
const int UX_FIELD = 2;
const int UX_COMPOUND = 3;
const int UX_VIEWGROUP = 5;
const int UX_TEXT = 7;
const int UX_IMAGE = 12;
const int UX_DECOR = 13;

/// Widget classifier using Set-based O(1) lookups for type matching.
class UXCamWidgetClassifier {
  static final UXCamWidgetClassifier _instance =
      UXCamWidgetClassifier._internal();
  factory UXCamWidgetClassifier() => _instance;
  UXCamWidgetClassifier._internal();

  static final Set<Type> _buttonTypes = {
    ElevatedButton,
    TextButton,
    OutlinedButton,
    FilledButton,
    InkWell,
    IconButton,
    FloatingActionButton,
    InkResponse,
    PopupMenuItem,
    ListTile,
    BackButton,
    CloseButton,
    DrawerButton,
    EndDrawerButton,
    MenuItemButton,
    SubmenuButton,
    SegmentedButton,
  };

  static final Set<Type> _chipTypes = {
    ActionChip,
    FilterChip,
    InputChip,
    ChoiceChip,
    RawChip,
  };

  static final Set<Type> _cupertinoButtonTypes = {
    CupertinoButton,
    CupertinoContextMenuAction,
    CupertinoDialogAction,
    CupertinoListTile,
    CupertinoNavigationBarBackButton,
  };

  static final Set<Type> _interactiveTypes = {
    Radio,
    Slider,
    Switch,
    Checkbox,
    CupertinoSwitch,
    CupertinoSlider,
    DropdownButton,
    RangeSlider,
    ToggleButtons,
  };

  static final Set<Type> _fieldTypes = {
    TextField,
    TextFormField,
    CupertinoTextField,
    EditableText,
    CupertinoSearchTextField,
  };

  static final Set<Type> _textTypes = {
    Text,
    RichText,
    SelectableText,
  };

  static final Set<Type> _imageTypes = {
    Image,
    Icon,
    ImageIcon,
    CircleAvatar,
  };

  static final Set<Type> _viewGroupTypes = {
    Scaffold,
    ListView,
    SingleChildScrollView,
    GridView,
    BottomSheet,
    AlertDialog,
    SimpleDialog,
    Dialog,
    CupertinoAlertDialog,
    CupertinoPopupSurface,
    BottomNavigationBar,
    NavigationRail,
    NavigationBar,
    TabBar,
    Drawer,
    Card,
  };

  static final Set<Type> _overlayTypes = {
    BottomSheet,
    AlertDialog,
    SimpleDialog,
    Dialog,
    CupertinoAlertDialog,
    CupertinoPopupSurface,
    PopupMenuButton,
    DropdownButtonFormField,
  };

  static final Set<Type> _customButtonTypes = {};
  static final Set<Type> _customFieldTypes = {};
  static final Set<Type> _customInteractiveTypes = {};

  static final Map<Type, String> _knownTypeNames = {
    ElevatedButton: 'ElevatedButton',
    TextButton: 'TextButton',
    OutlinedButton: 'OutlinedButton',
    FilledButton: 'FilledButton',
    IconButton: 'IconButton',
    FloatingActionButton: 'FloatingActionButton',
    GestureDetector: 'GestureDetector',
    InkWell: 'InkWell',
    InkResponse: 'InkResponse',
    PopupMenuItem: 'PopupMenuItem',
    ListTile: 'ListTile',
    BackButton: 'BackButton',
    CloseButton: 'CloseButton',
    MenuItemButton: 'MenuItemButton',
    SubmenuButton: 'SubmenuButton',
    SegmentedButton: 'SegmentedButton',
    // Chip types
    ActionChip: 'ActionChip',
    FilterChip: 'FilterChip',
    InputChip: 'InputChip',
    ChoiceChip: 'ChoiceChip',
    RawChip: 'RawChip',
    CupertinoButton: 'CupertinoButton',
    CupertinoContextMenuAction: 'CupertinoContextMenuAction',
    CupertinoDialogAction: 'CupertinoDialogAction',
    CupertinoListTile: 'CupertinoListTile',
    CupertinoNavigationBarBackButton: 'CupertinoNavigationBarBackButton',
    Radio: 'Radio',
    Slider: 'Slider',
    Switch: 'Switch',
    Checkbox: 'Checkbox',
    CupertinoSwitch: 'CupertinoSwitch',
    CupertinoSlider: 'CupertinoSlider',
    DropdownButton: 'DropdownButton',
    RangeSlider: 'RangeSlider',
    ToggleButtons: 'ToggleButtons',
    TextField: 'TextField',
    TextFormField: 'TextFormField',
    CupertinoTextField: 'CupertinoTextField',
    EditableText: 'EditableText',
    CupertinoSearchTextField: 'CupertinoSearchTextField',
    Text: 'Text',
    RichText: 'RichText',
    SelectableText: 'SelectableText',
    Image: 'Image',
    Icon: 'Icon',
    DecoratedBox: 'DecoratedBox',
    ImageIcon: 'ImageIcon',
    CircleAvatar: 'CircleAvatar',
    Scaffold: 'Scaffold',
    ListView: 'ListView',
    GridView: 'GridView',
    SingleChildScrollView: 'SingleChildScrollView',
    Card: 'Card',
    Material: 'Material',
  };

  static void registerButtonType(Type type) => _customButtonTypes.add(type);

  static void registerFieldType(Type type) => _customFieldTypes.add(type);

  static void registerInteractiveType(Type type) =>
      _customInteractiveTypes.add(type);

  static void unregisterButtonType(Type type) =>
      _customButtonTypes.remove(type);

  static void unregisterFieldType(Type type) => _customFieldTypes.remove(type);

  static void unregisterInteractiveType(Type type) =>
      _customInteractiveTypes.remove(type);

  static void clearCustomTypes() {
    _customButtonTypes.clear();
    _customFieldTypes.clear();
    _customInteractiveTypes.clear();
  }

  static int classify(Type runtimeType) {
    if (_customButtonTypes.contains(runtimeType)) return UX_BUTTON;
    if (_customFieldTypes.contains(runtimeType)) return UX_FIELD;
    if (_customInteractiveTypes.contains(runtimeType)) return UX_COMPOUND;

    if (_buttonTypes.contains(runtimeType) ||
        _cupertinoButtonTypes.contains(runtimeType) ||
        _chipTypes.contains(runtimeType)) {
      return UX_BUTTON;
    }

    if (_fieldTypes.contains(runtimeType)) return UX_FIELD;
    if (_interactiveTypes.contains(runtimeType)) return UX_COMPOUND;
    if (_textTypes.contains(runtimeType)) return UX_TEXT;
    if (_imageTypes.contains(runtimeType)) return UX_IMAGE;
    if (_viewGroupTypes.contains(runtimeType)) return UX_VIEWGROUP;

    return UX_UNKNOWN;
  }

  static int classifyElement(Element element) {
    final widget = element.widget;
    final runtimeType = widget.runtimeType;

    int type = classify(runtimeType);
    if (type != UX_UNKNOWN) return type;

    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        if (decoration.image != null) {
          return UX_IMAGE;
        }
        if (decoration.shape == BoxShape.circle || decoration.color != null) {
          return UX_DECOR;
        }
      }
      if (decoration is ShapeDecoration) {
        if (decoration.image != null) {
          return UX_IMAGE;
        }
        if (decoration.shape == BoxShape.circle || decoration.color != null) {
          return UX_DECOR;
        }
      }
    }

    final typeName = runtimeType.toString();
    if (typeName.startsWith('Radio<')) return UX_COMPOUND;

    return UX_UNKNOWN;
  }

  static String getDisplayName(Type runtimeType) {
    final knownName = _knownTypeNames[runtimeType];
    if (knownName != null) return knownName;

    final stringName = runtimeType.toString();
    if (_looksObfuscated(stringName)) {
      return _getGenericNameForType(classify(runtimeType));
    }

    return stringName;
  }

  static bool _looksObfuscated(String name) {
    if (name.length <= 3) {
      final cleaned = name.replaceAll(RegExp(r'[<>]'), '');
      return cleaned == cleaned.toLowerCase() &&
          RegExp(r'^[a-z]+$').hasMatch(cleaned);
    }
    return false;
  }

  static String _getGenericNameForType(int type) {
    switch (type) {
      case UX_BUTTON:
        return 'Button';
      case UX_FIELD:
        return 'TextField';
      case UX_COMPOUND:
        return 'Interactive';
      case UX_TEXT:
        return 'Text';
      case UX_IMAGE:
        return 'Image';
      case UX_DECOR:
        return 'Decoration';
      case UX_VIEWGROUP:
        return 'Container';
      case UX_CUSTOM:
        return 'CustomWidget';
      default:
        return 'Widget';
    }
  }

  static bool isOverlayType(Type runtimeType) =>
      _overlayTypes.contains(runtimeType);

  static bool isButton(Type runtimeType) =>
      _buttonTypes.contains(runtimeType) ||
      _cupertinoButtonTypes.contains(runtimeType) ||
      _customButtonTypes.contains(runtimeType);

  static bool isField(Type runtimeType) =>
      _fieldTypes.contains(runtimeType) ||
      _customFieldTypes.contains(runtimeType);

  static bool isInteractive(Type runtimeType) =>
      isButton(runtimeType) ||
      isField(runtimeType) ||
      _interactiveTypes.contains(runtimeType) ||
      _customInteractiveTypes.contains(runtimeType);
}
