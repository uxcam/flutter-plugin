import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam_example/dialogs_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initial Configuration to integrate UXCam to the app.
    // For Example this is created and place here. Please use this
    // configuration code in your service layer for ease of access
    // and better management.

    // Confirm that you have use/r permission for screen recording
    // FlutterUxcam.optIntoSchematicRecordings();

    // // Configuration
    FlutterUxConfig config = FlutterUxConfig(
      userAppKey: 'UXCAM_APP_KEY',
      // Important as this is handled by automatic screenTagging https://developer.uxcam.com/docs/tag-of-screens#control-automatic-tagging
      enableAutomaticScreenNameTagging: true,
      enableIntegrationLogging: true,
    );

    FlutterUxcam.startWithConfiguration(config);

    return MaterialApp(
      navigatorObservers: [FlutterUxcamNavigatorObserver()],
      routes: {
        '/pageview': (_) => const PageViewDemoPage(),
        '/occlusion-stress': (_) => const OcclusionStressPage(),
      },
      home: UXCamPage(),
    );
  }
}

class UXCamPage extends StatelessWidget {
  const UXCamPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          FeatureSection(
            title: 'Interactive Demo Screen',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StatelessScreen(),
                ),
              );
            },
            buttonTitle: 'Go to Interactive Demo',
          ),
          FeatureSection(
            title: 'PageView with Random Text',
            onPressed: () {
              Navigator.of(context).pushNamed('/pageview');
            },
            buttonTitle: 'Open PageView',
          ),
          FeatureSection(
            title: 'Spinning Colored Box',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SpinningBoxPage(),
                ),
              );
            },
            buttonTitle: 'Open Spinning Box',
          ),
          FeatureSection(
            title: 'Open Dialog',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Hello'),
                  content: const Text('This is a dialog.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            buttonTitle: 'Show Dialog',
          ),
          FeatureSection(
            occlude: true,
            title: 'Setting User Property**',
            onPressed: () => FlutterUxcam.setUserProperty(
                'userPropKeyString', 'valueString'),
            buttonTitle: 'Set User Property',
          ),
          FeatureSection(
            title: 'Custom Event**',
            onPressed: () => FlutterUxcam.logEvent('Custom Event'),
            buttonTitle: 'Custom Event',
          ),
          FeatureSection(
            title: 'Open Bottom Sheet',
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                builder: (_) => Container(
                  padding: const EdgeInsets.all(16),
                  height: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bottom Sheet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('This is a modal bottom sheet.'),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
            buttonTitle: 'Show Bottom Sheet',
          ),

          /// 1. Tagging Screen Manually
          FeatureSection(
            title: 'Screen Tagging',
            onPressed: () {
              FlutterUxcam.tagScreenName('Example Screen');
              showModalBottomSheet(
                  context: context,
                  builder: (_) {
                    return Builder(
                      builder: (context) => Container(
                        height: 100,
                        color: Colors.white,
                        child: Center(
                          child: Text(
                            'Screen Tagged as "Example Screen"',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    );
                  });
            },
            buttonTitle: 'Tag Screen',
          ),
          FeatureSection(
            title: 'Setting User Identity1',
            onPressed: () =>
                Navigator.of(context).pushNamed('/occlusion-stress'),
            buttonTitle: 'Set User Identity',
          ),
          FeatureSection(
            title: 'Custom Event With Properties',
            onPressed: () =>
                FlutterUxcam.logEventWithProperties('Custom Event', {
              'Property 1': 12345,
            }),
            buttonTitle: 'Custom Event with Property',
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
          FeatureSection(
            title: 'Dialogs Demo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DialogsPage(),
              ),
            ),
            buttonTitle: 'Open Dialogs Demo',
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
  final bool occlude;

  const FeatureSection({
    Key? key,
    required this.title,
    required this.onPressed,
    required this.buttonTitle,
    this.occlude = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        occlude
            ? OccludeWrapper(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              )
            : Text(
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

class StatelessScreen extends StatelessWidget {
  const StatelessScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interactive Demo')),
      body: Container(),
    );
  }
}

class InteractiveDemoPage extends StatefulWidget {
  const InteractiveDemoPage({Key? key}) : super(key: key);

  @override
  State<InteractiveDemoPage> createState() => _InteractiveDemoPageState();
}

class _InteractiveDemoPageState extends State<InteractiveDemoPage> {
  final List<bool> _switchStates = List<bool>.filled(20, false);
  double _sliderValue = 0.3;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interactive Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Type something',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust value: ${_sliderValue.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _sliderValue,
                onChanged: (v) => setState(() => _sliderValue = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            _switchStates.length,
            (i) => SwitchListTile(
              title: Text('Interactive Switch #${i + 1}'),
              value: _switchStates[i],
              onChanged: (v) => setState(() => _switchStates[i] = v),
            ),
          ),
        ],
      ),
    );
  }
}

class SpinningBoxPage extends StatefulWidget {
  const SpinningBoxPage({Key? key}) : super(key: key);

  @override
  State<SpinningBoxPage> createState() => _SpinningBoxPageState();
}

class _SpinningBoxPageState extends State<SpinningBoxPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spinning Colored Box')),
      body: Center(
        child: RotationTransition(
          turns: _controller,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.primaries.first,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class PageViewDemoPage extends StatefulWidget {
  const PageViewDemoPage({Key? key}) : super(key: key);

  @override
  State<PageViewDemoPage> createState() => _PageViewDemoPageState();
}

class _PageViewDemoPageState extends State<PageViewDemoPage> {
  late final List<String> _texts;

  @override
  void initState() {
    super.initState();
    _texts = ["page1", "page2", "page3"];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PageView Demo')),
      body: PageView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: false
                  ? OccludeWrapper(
                      child: Text(
                        _texts[index],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    )
                  : Text(
                      _texts[index],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class OcclusionStressPage extends StatefulWidget {
  const OcclusionStressPage({Key? key});

  @override
  State<OcclusionStressPage> createState() => _OcclusionStressPageState();
}

class _OcclusionStressPageState extends State<OcclusionStressPage> {
  final _controllers =
      List.generate(20, (index) => TextEditingController(text: 'Field $index'));

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Occlusion Stress Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              // force an extra occlusion pass to mimic native requests
              // FlutterUxcam.appendGestureContent(
              //   const Offset(0, 0),
              //   TrackData(
              //       Rect.zero, "/"), // supply your own TrackData if needed
              // );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _controllers.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _controllers[index],
              decoration: InputDecoration(
                labelText: 'Sensitive Field ${index + 1}',
                border: const OutlineInputBorder(),
              ),
            ),
          );
        },
      ),
    );
  }
}
