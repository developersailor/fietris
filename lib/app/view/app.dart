import 'package:fietris/game/fietris_game.dart';
import 'package:fietris/ui/on_screen_controls.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppView();
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2A48DF),
        appBarTheme: const AppBarTheme(color: Color(0xFF2A48DF)),
        colorScheme: ColorScheme.fromSwatch(
          accentColor: const Color(0xFF2A48DF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2A48DF)),
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: Scaffold(
        body: GameWidget<FietrisGame>.controlled(
          gameFactory: FietrisGame.new,
          overlayBuilderMap: {
            'onScreenControls': (context, game) =>
                OnScreenControlsWidget(game: game),
            'pauseScreen': (context, game) => PauseScreen(game: game),
          },
          initialActiveOverlays: const ['onScreenControls'],
        ),
      ),
    );
  }
}

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
