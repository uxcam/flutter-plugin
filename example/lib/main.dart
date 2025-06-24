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
      //userAppKey: 'gekzt6bh5299e09',
      userAppKey: 'vwaxl2b5nx8i10z',
      // Important as this is handled by automatic screenTagging https://developer.uxcam.com/docs/tag-of-screens#control-automatic-tagging
      enableAutomaticScreenNameTagging: true,
      enableIntegrationLogging: true,
    );

    FlutterUxcam.startWithConfiguration(config);

    return UXCamGestureHandler(
      child: MaterialApp(
        initialRoute: "/",
        onGenerateRoute: onGenerateRoute,
        navigatorObservers: [FlutterUxcamNavigatorObserver()],
      ),
    );
  }
}

class UXCamPage extends StatelessWidget {
  const UXCamPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
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
      // body: ListView(
      //   padding: const EdgeInsets.all(8.0),
      //   children: [
      //     Text(
      //       "This is a smart events demo",
      //       style: Theme.of(context).textTheme.headlineSmall,
      //     ),
      //     Image.asset("assets/images/testimage.jpg"),
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
      //   ],
      // ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (_) {
                return AlertDialog(
                  //title: const Text('Feature Section'),
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
        builder: (_) => const UserFormFirstPage(),
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

// class DetailPage extends StatelessWidget {
//   const DetailPage({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         children: [
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//           ElevatedButton(onPressed: () {}, child: Text("data")),
//         ],
//       ),
//     );
//   }
// }

class UserFormFirstPage extends StatefulWidget {
  const UserFormFirstPage({Key? key});

  @override
  State<UserFormFirstPage> createState() => _UserFormFirstPage();
}

class _UserFormFirstPage extends State<UserFormFirstPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isVisible = false;
  bool _isAddressVisible = false;

  String _firstName = '';
  String _middleName = '';
  String _lastName = '';
  String _address = '';
  String _month = '';
  String _day = '';
  String _year = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("User Information Form Two Top level Occlusion Wrapper"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First Name TextField
                Visibility(
                  visible: _isVisible,
                  child: OccludeWrapper(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _firstName = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Middle Name TextField
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Middle Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _middleName = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your middle name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Last Name TextField
                OccludeWrapper(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _lastName = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 16),

                if (_isAddressVisible)
                  OccludeWrapper(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Address Field',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _address = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                  ),

                const SizedBox(height: 50),

                Text("""Whether to show or hide a child.
                  By default, the visible property controls whether the child is included in the subtree or not; 
                  when it is not visible, the replacement child (typically a zero-sized box) is included instead.
                  A variety of flags can be used to tweak exactly how the child is hidden. 
                  (Changing the flags dynamically is discouraged, as it can cause the child subtree to be rebuilt, with any state in the subtree being discarded. 
                  Typically, only the visible flag is changed dynamically.)"""),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OccludeWrapper(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isVisible = !_isVisible;
                          });
                        },
                        child: Text(
                            _isVisible ? 'Hide First Name' : 'Show First Name'),
                      ),
                    ),
                    OccludeWrapper(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isAddressVisible = !_isAddressVisible;
                          });
                        },
                        child: Text(_isAddressVisible
                            ? 'Show Address Field'
                            : 'Hide Address Field'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
