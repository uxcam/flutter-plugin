# flutter_uxcam

UXCam plugin for Flutter.

## Installation

Open the `pubspec.yaml` file located inside your app folder and add `flutter_uxcam:` under dependencies.

On iOS, Flutter 3.44 and later uses Swift Package Manager by default. The plugin also continues to support CocoaPods; both integrations use UXCam `3.8.x` and require iOS 13 or later.

## Usage
Inside your dart file import flutter_uxcam like this

`import 'package:flutter_uxcam/flutter_uxcam.dart';`

Then inside the first method that gets called add the following code snippets; most likely inside the class of `lib/main.dart` file that's getting called by this `void main() => runApp(MyApp());` where `MyApp` is the name of your class.
`FlutterUxConfig config = FlutterUxConfig(userAppKey: "UXCAM_APP_KEY");`
`FlutterUxcam.startWithConfiguration(config);`
>UXCAM_APP_KEY is available at https://uxcam.com 

### Example
```
import 'package:flutter_uxcam/flutter_uxcam.dart';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    FlutterUxcam.optIntoSchematicRecordings(); // Confirm that you have user permission for screen recording
    FlutterUxConfig config = FlutterUxConfig(userAppKey: "UXCAM_APP_KEY");
    FlutterUxcam.startWithConfiguration(config);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
```
If you get this error while running in iOS
>    Error output from CocoaPods:
>    ↳
>
>    [!] Automatically assigning platform `ios` with version `8.0` on target `Runner` because no platform was specified. Please specify a platform for this target in your
>    Podfile. See `https://guides.cocoapods.org/syntax/podfile.html#platform`.

Then inside the `ios` folder, set the deployment target in the `Podfile` to iOS 13 or later, for example `platform :ios, '13.0'`.
