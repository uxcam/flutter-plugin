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
        userAppKey: 'key',
        //userAppKey: 'vwaxl2b5nx8i10z',
        // Important as this is handled by automatic screenTagging https://developer.uxcam.com/docs/tag-of-screens#control-automatic-tagging
        enableAutomaticScreenNameTagging: false,
        enableIntegrationLogging: true);

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
      // body: IndexedStack(
      //   children: [
      //     Container(
      //       child: Text("data1"),
      //     ),
      //     Container(
      //       child: Text("data2"),
      //     ),
      //     Container(
      //       child: Text("data3"),
      //     ),
      //     Container(
      //       child: Text("data4"),
      //     ),
      //   ],
      // ),
      // body: Column(
      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //   crossAxisAlignment: CrossAxisAlignment.stretch,
      //   children: [
      //     ElevatedButton(
      //         onPressed: () {
      //           showDialog(
      //               context: context,
      //               builder: (_) {
      //                 return AlertDialog(
      //                   actions: [Text('data')],
      //                 );
      //               });
      //         },
      //         child: Text('data')),
      //     ElevatedButton(onPressed: () {}, child: Text('data')),
      //     ElevatedButton(onPressed: () {}, child: Text('data')),
      //   ],
      // ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          Text(
            "This is a smart events demo",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Image.asset("assets/images/testimage.jpg"),
          TextField(
            decoration: InputDecoration(hintText: "this is a hint"),
          ),
          TextFormField(),
          FeatureSection(
            title: 'Screen Tagging',
            onPressed: () => FlutterUxcam.tagScreenName('Example Screen'),
            buttonTitle: 'Login',
          ),
          FeatureSection(
            title: 'Navigate',
            onPressed: () => Navigator.of(context).pushNamed("detail"),
            buttonTitle: 'Navigate to details',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (_) {
                return AlertDialog(
                  title: const Text('Feature Section'),
                  content: Text("data"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              });
          // showModalBottomSheet(
          //     context: context,
          //     builder: (_) => Container(
          //           color: Colors.amber,
          //           child: Align(
          //             alignment: Alignment.bottomCenter,
          //             child:
          //                 ElevatedButton(onPressed: () {}, child: Text("data")),
          //           ),
          //         ));
        },
        child: const Icon(Icons.add),
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
