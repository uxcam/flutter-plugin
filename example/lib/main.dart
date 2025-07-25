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
        //userAppKey: 'key',
        userAppKey: 'vwaxl2b5nx8i10z',
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
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: true ? Colors.grey : Colors.blue,
                child: Icon(Icons.abc, color: Colors.white),
              ),
              title: Text(
                "Test",
                style: TextStyle(
                  fontWeight: true ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("message"),
                  const SizedBox(height: 4),
                  Text(
                    "time",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: false
                  ? null
                  : const CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.blue,
                    ),
              onTap: () {
                // FlutterUxcam.logEventWithProperties('Notification Tapped',
                //     {
                //   'title': title,
                //   'isRead': isRead,
                // }
                // );
                // Handle notification tap
              },
            ),
          ),
          Text(
            "This is a smart events demo",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Image.asset(
            "assets/images/testimage.jpg",
            //semanticLabel: "this is a test image",
          ),
          Container(
            height: 300,
            decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/images/testimage.jpg"))),
          ),
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
      // ElevatedButton(onPressed: () {}, child: Text('data')),
      // TextField(
      //   decoration: InputDecoration(hintText: "this is a hint"),
      // ),
      // ElevatedButton(
      //     onPressed: () {
      //       showDialog(
      //           context: context,
      //           builder: (_) {
      //             return AlertDialog(
      //               title: const Text('Feature Section'),
      //               content: Text("data"),
      //               actions: [
      //                 TextButton(
      //                   onPressed: () => Navigator.of(context).pop(),
      //                   child: const Text('Close'),
      //                 ),
      //               ],
      //             );
      //           });
      //     },
      //     child: Text('data')),
      // CheckboxListTile(
      //   title: const Text('Crash Handling'),
      //   subtitle: const Text(
      //     '(Enabled By Default)',
      //     style: TextStyle(fontSize: 12),
      //   ),
      //   value: false,
      //   onChanged: (value) => {},
      // ),
      // Row(
      //   children: [
      //     Checkbox(value: false, onChanged: (v) {}),
      //     Text('yes'),
      //     Checkbox(value: false, onChanged: (v) {}),
      //     Text('no')
      //   ],
      // ),
      // Row(
      //   children: [Checkbox(value: false, onChanged: (v) {}), Text('no')],
      // ),
      // Row(
      //   children: [
      //     Text('maybe'),
      //     Checkbox(value: false, onChanged: (v) {}),
      //     Text('yes'),
      //     Checkbox(value: false, onChanged: (v) {}),
      //     Text('no'),
      //     Checkbox(value: false, onChanged: (v) {})
      //   ],
      // ),
      // Row(
      //   children: [Text('no'), Checkbox(value: false, onChanged: (v) {})],
      // ),
      // ElevatedButton(
      //     onPressed: () {
      //       Navigator.of(context).pushNamed("detail");
      //     },
      //     child: Text('data')),
      //    ],
      //),
      // body: Row(
      //   children: [
      //     Text(
      //       "radio",
      //       style: Theme.of(context).textTheme.headlineSmall,
      //     ),
      //     Radio(value: true, groupValue: false, onChanged: (val) {}),
      //   ],
      // ),
      // body: ListView(
      //   padding: const EdgeInsets.all(8.0),
      //   children: [
      //     Text(
      //       "This is a smart events demo",
      //       style: Theme.of(context).textTheme.headlineSmall,
      //     ),
      //     Image.asset(
      //       "assets/images/testimage.jpg",
      //       semanticLabel: "this is a test image",
      //     ),
      //     TextField(
      //       decoration: InputDecoration(hintText: "this is a hint"),
      //     ),
      //     TextFormField(),
      //     FeatureSection(
      //       title: 'Screen Tagging',
      //       onPressed: () => FlutterUxcam.tagScreenName('Example Screen'),
      //       buttonTitle: 'Login',
      //     ),
      //     TextButton(onPressed: () {}, child: Text("Signup")),
      //     Column(
      //       children: [
      //         Radio(value: true, groupValue: false, onChanged: (val) {}),
      //         Text(
      //           "radio",
      //           style: Theme.of(context).textTheme.headlineSmall,
      //         ),
      //       ],
      //     ),
      //     Column(
      //       children: [
      //         Slider(value: 0, onChanged: (x) {}),
      //         Text(
      //           "slider",
      //           style: Theme.of(context).textTheme.headlineSmall,
      //         ),
      //       ],
      //     ),
      //   ],
      // ),
      // body: Row(
      //   children: [
      //     Radio(value: true, groupValue: false, onChanged: (val) {}),
      // Text(
      //   "radio",
      //   style: Theme.of(context).textTheme.headlineSmall,
      // ),
      //   ],
      // ),
      // bottomNavigationBar: BottomNavigationWidget(
      //   currentIndex: 0,
      //   onTap: (i) {},
      // ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     showDialog(
      //         context: context,
      //         builder: (_) {
      //           return AlertDialog(
      //             title: const Text('Feature Section'),
      //             content: Text("data"),
      //             actions: [
      //               TextButton(
      //                 onPressed: () => Navigator.of(context).pop(),
      //                 child: const Text('Close'),
      //               ),
      //             ],
      //           );
      //         });
      //     // showModalBottomSheet(
      //     //     context: context,
      //     //     builder: (_) => Container(
      //     //           color: Colors.amber,
      //     //           child: Align(
      //     //             alignment: Alignment.bottomCenter,
      //     //             child:
      //     //                 ElevatedButton(onPressed: () {}, child: Text("data")),
      //     //           ),
      //     //         ));
      //   },
      //   child: const Icon(Icons.add),
      // ),
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
