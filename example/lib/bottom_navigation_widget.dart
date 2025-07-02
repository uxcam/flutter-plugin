import 'package:flutter/material.dart';

typedef OnBottomNavigationTapped = void Function(int value);

class BottomNavigationWidget extends StatelessWidget {
  final int currentIndex;
  final OnBottomNavigationTapped onTap;

  const BottomNavigationWidget({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.white,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          label: 'API',
          icon: Icon(Icons.share),
        ),
        BottomNavigationBarItem(
          label: 'UI',
          icon: Icon(Icons.star),
        ),
        BottomNavigationBarItem(
          label: 'Testing',
          icon: Icon(Icons.hot_tub_rounded),
        ),
        BottomNavigationBarItem(
          label: 'Settings',
          icon: Icon(Icons.settings),
        ),
      ],
    );
  }
}
