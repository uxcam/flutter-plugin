import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_uxcam/src/widgets/textfield_occlusion_policy.dart';

void main() {
  group('source model: configuration can only ADD, API otherwise decides', () {
    test('off by default', () {
      expect(TextFieldOcclusionPolicy().effective, isFalse);
    });

    test('manual API alone enables/disables', () {
      final policy = TextFieldOcclusionPolicy()..manualBase = true;
      expect(policy.effective, isTrue);
      policy.manualBase = false;
      expect(policy.effective, isFalse);
    });

    test('config=true enables regardless of the API', () {
      final policy = TextFieldOcclusionPolicy()..manualBase = false;
      policy.applyNativeSettings({'occludeAllTextFields': true},
          isConfigSource: true);
      expect(policy.effective, isTrue);
      policy.manualBase = false;
      expect(policy.effective, isTrue,
          reason: 'a manual call cannot switch off delivered configuration');
    });

    test('config=false cannot veto the API', () {
      final policy = TextFieldOcclusionPolicy()..manualBase = true;
      policy.applyNativeSettings({'occludeAllTextFields': false},
          isConfigSource: true);
      expect(policy.effective, isTrue,
          reason: 'the server can only add occlusion, never remove it — '
              'matching UXCam iOS/Android, where the dashboard has no '
              'representable "do not occlude" and a developer call survives');
    });

    test('config=false with no API call stays off', () {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings({'occludeAllTextFields': false},
          isConfigSource: true);
      expect(policy.effective, isFalse);
    });
  });

  group('per-capture payloads can enable, never disable', () {
    test(
        'iOS verification path: no config statement, API never called, '
        'native pushes true — masking must switch on', () {
      final policy = TextFieldOcclusionPolicy();

      // The iOS SDK sends no `updateOcclusionConfiguration`, so `requestSceneFrame`
      // is the *only* channel a verification response has on that platform.
      // Ignoring it left a dashboard-enabled app entirely unmasked in Flutter.
      policy.applyNativeSettings(
          {'occludeAllTextFields': true, 'currentScreen': 'Login'},
          isConfigSource: false);
      expect(policy.effective, isTrue);
    });

    test('a per-capture false cannot disable what the API asked for', () {
      final policy = TextFieldOcclusionPolicy()..manualBase = true;

      // Native resolves the per-capture value as the union of the dashboard rule
      // and the developer's own call, and the API call reaches native
      // asynchronously — so a capture in flight can still report the old value.
      // Ranking it above the API is what made `occludeAllTextFields` a no-op
      // once any capture had happened.
      policy.applyNativeSettings({'occludeAllTextFields': false},
          isConfigSource: false);
      expect(policy.effective, isTrue);
    });

    test('with every source silent or off, masking stays off', () {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings({'occludeAllTextFields': false},
          isConfigSource: false);
      expect(policy.effective, isFalse);

      policy.manualBase = false;
      expect(policy.effective, isFalse);
    });

    test('a per-capture flag tracks native both ways while nothing else asks',
        () {
      final policy = TextFieldOcclusionPolicy();
      for (final flag in [true, false, true, false]) {
        policy.applyNativeSettings({'occludeAllTextFields': flag},
            isConfigSource: false);
        expect(policy.effective, flag,
            reason: 'a screen-scoped dashboard rule resolves per screen '
                'natively, so the value must be allowed to fall as well as rise');
      }
    });

    test('per-capture payloads still carry currentScreen', () {
      final policy = TextFieldOcclusionPolicy();
      expect(
          policy.applyNativeSettings({'currentScreen': 'Checkout'},
              isConfigSource: false),
          isTrue);
      expect(policy.currentScreen, 'Checkout');
    });
  });

  group('screen rules scope the configuration rule only', () {
    TextFieldOcclusionPolicy configured(Map<String, dynamic> statement) {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings(statement, isConfigSource: true);
      return policy;
    }

    test('an unscoped config rule applies to all screens', () {
      final policy = configured({'occludeAllTextFields': true});
      policy.currentScreen = 'AnyScreen';
      expect(policy.effective, isTrue);
    });

    test('include mode: the config rule applies only on listed screens', () {
      final policy = configured({
        'occludeAllTextFields': true,
        'screens': ['Login', 'Payment'],
        'excludeMentionedScreens': false,
      });

      policy.currentScreen = 'Login';
      expect(policy.effective, isTrue);
      policy.currentScreen = 'Home';
      expect(policy.effective, isFalse);
    });

    test('exclude mode: the config rule applies everywhere except listed', () {
      final policy = configured({
        'occludeAllTextFields': true,
        'screens': ['Search'],
        'excludeMentionedScreens': true,
      });

      policy.currentScreen = 'Search';
      expect(policy.effective, isFalse);
      policy.currentScreen = 'Login';
      expect(policy.effective, isTrue);
    });

    test('unknown current screen fails safe (over-occludes) in exclude mode',
        () {
      final policy = configured({
        'occludeAllTextFields': true,
        'screens': ['Search'],
        'excludeMentionedScreens': true,
      })
        ..currentScreen = null;
      expect(policy.effective, isTrue);
    });

    test('the config scope never narrows the blanket manual API', () {
      final policy = configured({
        'occludeAllTextFields': true,
        'excludeScreens': ['Search'],
      })
        ..manualBase = true
        ..currentScreen = 'Search';

      expect(policy.effective, isTrue,
          reason: 'the API takes no screen argument, so it is blanket — '
              'honouring the server exclusion here would let the server '
              'remove occlusion the developer asked for');
    });

    test('a config scope on a disabled config rule changes nothing', () {
      final policy = configured({
        'occludeAllTextFields': false,
        'screens': ['Login'],
      })
        ..currentScreen = 'Login';
      expect(policy.effective, isFalse);

      policy.manualBase = true;
      policy.currentScreen = 'Home';
      expect(policy.effective, isTrue);
    });
  });

  group('applyNativeSettings parsing', () {
    test('ignores non-map and unrecognised payloads', () {
      final policy = TextFieldOcclusionPolicy();
      expect(policy.applyNativeSettings(null, isConfigSource: true), isFalse);
      expect(policy.applyNativeSettings('nope', isConfigSource: true), isFalse);
      expect(
          policy.applyNativeSettings(<String, dynamic>{}, isConfigSource: true),
          isFalse);
      expect(policy.applyNativeSettings({'unrelated': 1}, isConfigSource: true),
          isFalse);
    });

    test('type mismatches are ignored', () {
      final policy = TextFieldOcclusionPolicy();
      expect(
          policy.applyNativeSettings({'occludeAllTextFields': 'yes'},
              isConfigSource: true),
          isFalse);
      expect(policy.effective, isFalse);
    });

    test('excludeScreens shorthand = applies everywhere except listed', () {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings({
        'occludeAllTextFields': true,
        'excludeScreens': ['Search', 42, 'Help'], // non-strings dropped
      }, isConfigSource: true);
      expect(policy.excludeMentionedScreens, isTrue);
      expect(policy.screens, ['Search', 'Help']);

      policy.currentScreen = 'Search';
      expect(policy.effective, isFalse);
      policy.currentScreen = 'Login';
      expect(policy.effective, isTrue);
    });

    test('currentScreen key updates the evaluated screen', () {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings({
        'occludeAllTextFields': true,
        'screens': ['Secret'],
        'excludeMentionedScreens': true,
      }, isConfigSource: true);
      policy.applyNativeSettings({'currentScreen': 'Secret'},
          isConfigSource: false);
      expect(policy.effective, isFalse);
    });
  });

  group('complete config statement semantics', () {
    test(
        'a config statement without the flag clears the config layer '
        'so the manual API stays in control when the dashboard has no setting',
        () {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings({
        'occludeAllTextFields': true,
        'excludeScreens': ['Search'],
      }, isConfigSource: true);
      policy.currentScreen = 'Search';
      expect(policy.effective, isFalse, reason: 'excluded screen');

      // Next session's config carries no text-field setting at all.
      policy.applyNativeSettings({'screens': <String>[]}, isConfigSource: true);
      expect(policy.configBase, isNull);
      expect(policy.effective, isFalse, reason: 'API never opted in');

      policy.manualBase = true;
      expect(policy.effective, isTrue,
          reason: 'unspecified config hands control back to the manual API');
    });

    test('a new config statement replaces the previous screen scope', () {
      final policy = TextFieldOcclusionPolicy();
      policy.applyNativeSettings({
        'occludeAllTextFields': true,
        'excludeScreens': ['Search'],
      }, isConfigSource: true);
      expect(policy.screens, ['Search']);

      policy.applyNativeSettings({'occludeAllTextFields': true},
          isConfigSource: true);
      expect(policy.screens, isEmpty,
          reason: 'scope absent from the new statement must be dropped');
      expect(policy.effective, isTrue);
    });

    test('per-capture values never touch the config-owned screen scope', () {
      final policy = TextFieldOcclusionPolicy()..manualBase = true;
      policy.applyNativeSettings({
        'occludeAllTextFields': true,
        'screens': ['X'],
        'excludeMentionedScreens': true,
      }, isConfigSource: false);
      expect(policy.screens, isEmpty);
      expect(policy.excludeMentionedScreens, isFalse);
      expect(policy.configBase, isNull);
    });

    test('clearConfiguration drops the config layer but keeps the API call',
        () {
      final policy = TextFieldOcclusionPolicy()..manualBase = false;
      policy.applyNativeSettings({
        'occludeAllTextFields': true,
        'excludeScreens': ['Search'],
      }, isConfigSource: true);
      expect(policy.effective, isTrue);

      expect(policy.clearConfiguration(), isTrue);
      expect(policy.configBase, isNull);
      expect(policy.screens, isEmpty);
      expect(policy.excludeMentionedScreens, isFalse);
      expect(policy.effective, isFalse);

      policy.manualBase = true;
      expect(policy.effective, isTrue);

      expect(policy.clearConfiguration(), isFalse,
          reason: 'nothing left to clear');
    });
  });
}
