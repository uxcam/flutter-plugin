# flutter_uxcam

UXCam plugin for Flutter.

## Installation

Open the `pubspec.yaml` file located inside your app folder and add `flutter_uxcam:` under dependencies.

## Usage
Inside your dart file import flutter_uxcam like this

`import 'package:flutter_uxcam/flutter_uxcam.dart';`

Then inside the first method that gets called add the following code snippets; most likely inside the class of `lib/main.dart` file that's getting called by this `void main() => runApp(MyApp());` where `MyApp` is the name of your class.
`FlutterUxcam.startWithKey("UXCAM_APP_KEY");`
>UXCAM_APP_KEY is available at https://uxcam.com 

### Example
```
import 'package:flutter_uxcam/flutter_uxcam.dart';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    FlutterUxcam.startWithKey("UXCAM_APP_KEY");
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
>    [!] Automatically assigning platform `ios` with version `8.0` on target `Runner` because no platform was specified. Please specify a platform for this target in your >    >    Podfile. See `https://guides.cocoapods.org/syntax/podfile.html#platform`.

Then inside `ios` folder in `pod` file uncomment this line `# platform :ios, '9.0'` that means removing `#`

This plugin doesn't fully support Android as of now.