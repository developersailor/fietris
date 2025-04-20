import 'package:fietris/game/fietris_game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

/// Mobil cihazlar için ekranda dokunmatik kontroller sağlayan component
class TouchControls extends PositionComponent {

  TouchControls({required this.game});
  final FietrisGame game;

  @override
  Future<void> onLoad() async {
    // Sol tuş
    final leftButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(60, 60),
        paint: Paint()..color = Colors.white.withOpacity(0.5),
      ),
      position: Vector2(50, game.size.y - 100),
      onPressed: () {
        if (game.currentBlock != null) {
          final potentialPosition = Vector2(
            game.currentBlock!.position.x - game.currentBlock!.cellSize,
            game.currentBlock!.position.y,
          );
          if (!game.checkCollision(game.currentBlock!, potentialPosition)) {
            game.currentBlock!.moveLeft();
          }
        }
      },
    );
    leftButton.add(
      TextComponent(
        text: '←',
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.black, fontSize: 32),
        ),
        anchor: Anchor.center,
        position: leftButton.size / 2,
      ),
    );
    await add(leftButton);

    // Sağ tuş
    final rightButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(60, 60),
        paint: Paint()..color = Colors.white.withOpacity(0.5),
      ),
      position: Vector2(150, game.size.y - 100),
      onPressed: () {
        if (game.currentBlock != null) {
          final potentialPosition = Vector2(
            game.currentBlock!.position.x + game.currentBlock!.cellSize,
            game.currentBlock!.position.y,
          );
          if (!game.checkCollision(game.currentBlock!, potentialPosition)) {
            game.currentBlock!.moveRight();
          }
        }
      },
    );
    rightButton.add(
      TextComponent(
        text: '→',
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.black, fontSize: 32),
        ),
        anchor: Anchor.center,
        position: rightButton.size / 2,
      ),
    );
    await add(rightButton);
  }
}
