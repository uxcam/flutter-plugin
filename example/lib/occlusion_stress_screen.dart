import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:flutter_uxcam/src/widgets/occlude_wrapper.dart';

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
            child: OccludeWrapper(
              child: TextField(
                controller: _controllers[index],
                decoration: InputDecoration(
                  labelText: 'Sensitive Field ${index + 1}',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
