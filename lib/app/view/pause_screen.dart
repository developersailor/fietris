import 'package:fietris/game/fietris_game.dart';
import 'package:flutter/material.dart';

class PauseScreen extends StatelessWidget {
  const PauseScreen({required this.game, super.key});
  final FietrisGame game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paused',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              game.togglePause();
            },
            child: const Text('Resume'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              game.restartGame();
              game.togglePause();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}
