import 'package:flutter/material.dart';

class PauseScreen extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onMainMenu;

  const PauseScreen({
    Key? key,
    required this.onResume,
    required this.onMainMenu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onResume,
            child: const Text('Resume'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onMainMenu,
            child: const Text('Main Menu'),
          ),
        ],
      ),
    );
  }
}
