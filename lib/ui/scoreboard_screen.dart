import 'package:flutter/material.dart';

class ScoreboardScreen extends StatelessWidget {
  final int playerScore;
  final List<int> topScores;

  const ScoreboardScreen({
    Key? key,
    required this.playerScore,
    required this.topScores,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your Score: $playerScore',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Top Scores:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < topScores.length; i++)
            Text(
              '${i + 1}. ${topScores[i]}',
              style: const TextStyle(fontSize: 18),
            ),
        ],
      ),
    );
  }
}
