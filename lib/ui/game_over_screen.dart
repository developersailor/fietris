import 'package:flutter/material.dart';

class GameOverScreen extends StatelessWidget {
  final VoidCallback onRestart;
  final VoidCallback onMainMenu;

  const GameOverScreen({
    Key? key,
    required this.onRestart,
    required this.onMainMenu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onRestart,
            child: const Text('Restart'),
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
