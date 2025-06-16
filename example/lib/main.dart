import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam_example/bottom_navigation_widget.dart';

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
      userAppKey: 'key',
      //userAppKey: 'vwaxl2b5nx8i10z',
      // Important as this is handled by automatic screenTagging https://developer.uxcam.com/docs/tag-of-screens#control-automatic-tagging
      enableAutomaticScreenNameTagging: false,
      enableIntegrationLogging: true,
    );

    FlutterUxcam.startWithConfiguration(config);

    return MaterialApp(
      initialRoute: "/",
      onGenerateRoute: onGenerateRoute,
      builder: (context, child) {
        return WidgetCapture(
          child: child!,
        );
      },
    );
  }
}

class UXCamPage extends StatelessWidget {
  const UXCamPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      //body: ListView(
      //children: [
      // Text(
      //   "data",
      //   style: TextStyle(fontSize: 20),
      // ),
      // Text(
      //   "data",
      //   style: TextStyle(fontSize: 20),
      // ),
      // Text(
      //   "data",
      //   style: TextStyle(fontSize: 20),
      // ),
      // Text(
      //   "data",
      //   style: TextStyle(fontSize: 20),
      // ),
      // TextField(
      //   obscureText: true,
      // ),
      // FeatureSection(
      //   title: 'Screen Tagging',
      //   onPressed: () => FlutterUxcam.tagScreenName('Example Screen'),
      //   buttonTitle: 'Tag Screen',
      // ),
      //],
      //),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          /// 1. Tagging Screen Manually
          OccludeWrapper(
            child: Text(
              "this text will be occluded",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
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
          OccludeWrapper(
            child: Text(
              "this text will be occluded",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FeatureSection(
            title: 'Custom Occlude',
            onPressed: () => FlutterUxcam.logEvent('Custom Event'),
            buttonTitle: 'Custom Event',
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
          OccludeWrapper(
            child: Text(
              "this text will be occluded",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
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
          OccludeWrapper(
            child: Text(
              "this text will be occluded",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FeatureSection(
            title: 'Custom Occlude',
            onPressed: () => FlutterUxcam.logEvent('Custom Event'),
            buttonTitle: 'Custom Event',
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
          TextField(
            obscureText: true,
          ),
        ],
      ),
    );
  }
}

class StatefulTest extends StatefulWidget {
  const StatefulTest({Key? key}) : super(key: key);

  @override
  State<StatefulTest> createState() => _StatefulTestState();
}

class _StatefulTestState extends State<StatefulTest> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
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
          child: Row(
            children: [
              const Icon(Icons.abc),
              Text(buttonTitle),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}

MaterialPageRoute<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case 'detail':
      return MaterialPageRoute(
        builder: (_) => const DetailPage(),
        settings: RouteSettings(
          arguments: settings.arguments,
          name: "detail",
        ),
      );
    default:
      return MaterialPageRoute(
        builder: (_) => const UXCamPage(),
        settings: RouteSettings(
          arguments: settings.arguments,
          name: "/",
        ),
      );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
          ElevatedButton(onPressed: () {}, child: Text("data")),
        ],
      ),
    );
  }
}
