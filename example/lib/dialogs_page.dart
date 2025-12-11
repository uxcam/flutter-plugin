import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

class DialogsPage extends StatelessWidget {
  const DialogsPage({Key? key}) : super(key: key);

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alert Dialog'),
          content: const Text('This is a standard alert dialog.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSimpleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Simple Dialog'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Option 1'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Option 2'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Option 3'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Custom Dialog',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('This is a custom styled dialog.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modal Bottom Sheet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('This is a modal bottom sheet with rounded corners.'),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Get link'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This is a SnackBar'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {},
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showMaterialBanner(BuildContext context) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('This is a Material Banner'),
        leading: const Icon(Icons.info),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
  }

  void _showTimePicker(BuildContext context) async {
    await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'UXCam Example',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.flutter_dash),
      children: [
        const Text('This is an example app demonstrating various dialogs.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialogs Demo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const OccludeWrapper(
            child: Text(
              'Dialog Types',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAlertDialog(context),
            icon: const Icon(Icons.warning),
            label: const Text('Alert Dialog'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showSimpleDialog(context),
            icon: const Icon(Icons.list),
            label: const Text('Simple Dialog'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showCustomDialog(context),
            icon: const Icon(Icons.star),
            label: const Text('Custom Dialog'),
          ),
          const Divider(height: 32),
          const Text(
            'Bottom Sheets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showModalBottomSheet(context),
            icon: const Icon(Icons.view_agenda),
            label: const Text('Modal Bottom Sheet'),
          ),
          const Divider(height: 32),
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showSnackBar(context),
            icon: const Icon(Icons.message),
            label: const Text('SnackBar'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showMaterialBanner(context),
            icon: const Icon(Icons.announcement),
            label: const Text('Material Banner'),
          ),
          const Divider(height: 32),
          const Text(
            'Pickers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showDatePicker(context),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Date Picker'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showTimePicker(context),
            icon: const Icon(Icons.access_time),
            label: const Text('Time Picker'),
          ),
          const Divider(height: 32),
          const Text(
            'Other',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAboutDialog(context),
            icon: const Icon(Icons.info),
            label: const Text('About Dialog'),
          ),
        ],
      ),
    );
  }
}
