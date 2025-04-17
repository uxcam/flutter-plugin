import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initial Configuration to integrate UXCam to the app.
    // For Example this is created and place here. Please use this
    // configuration code in your service layer for ease of access
    // and better management.

    // Confirm that you have user permission for screen recording
    FlutterUxcam.optIntoSchematicRecordings();

    // Configuration
    FlutterUxConfig config = FlutterUxConfig(
      userAppKey: 'USER_APP_KEY',
      // Important as this is handled by automatic screenTagging https://developer.uxcam.com/docs/tag-of-screens#control-automatic-tagging
      enableAutomaticScreenNameTagging: false,
    );

    FlutterUxcam.startWithConfiguration(config);

    return const MaterialApp(home: UXCamPage());
  }
}

class UXCamPage extends StatelessWidget {
  const UXCamPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          /// 1. Tagging Screen Manually
          FeatureSection(
            title: 'Screen Tagging',
            onPressed: () => FlutterUxcam.tagScreenName('Example Screen'),
            buttonTitle: 'Tag Screen',
          ),
          FeatureSection(
            title: 'Setting User Identity',
            onPressed: () => FlutterUxcam.setUserIdentity('Guest User'),
            buttonTitle: 'Set User Identity',
          ),
          FeatureSection(
            title: 'Setting User Property',
            onPressed: () => FlutterUxcam.setUserProperty(
                'userPropKeyString', 'valueString'),
            buttonTitle: 'Set User Property',
          ),
          FeatureSection(
            title: 'Custom Event',
            onPressed: () => FlutterUxcam.logEvent('Custom Event'),
            buttonTitle: 'Custom Event',
          ),
          FeatureSection(
            title: 'Custom Event With Properties',
            onPressed: () =>
                FlutterUxcam.logEventWithProperties('Custom Event', {
              'Property 1': 12345,
            }),
            buttonTitle: 'Custom Event with Property',
          ),
        ],
      ),
    );
  }
}

typedef OnFeatureButtonPressed = Function();

class FeatureSection extends StatelessWidget {
  final String title;
  final OnFeatureButtonPressed onPressed;
  final String buttonTitle;

  const FeatureSection({
    Key? key,
    required this.title,
    required this.onPressed,
    required this.buttonTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonTitle),
        ),
        const Divider(),
      ],
    );
  }
}
