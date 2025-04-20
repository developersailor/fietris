import 'package:fietris/game/fietris_game.dart';
import 'package:fietris/game/grid_data.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Yerleşen blokları görselleştiren component
class SettledBlocksComponent extends PositionComponent
    with HasGameRef<FietrisGame> {
  SettledBlocksComponent({
    required this.cellSize,
    required Vector2 position,
  }) : super(position: position);
  final double cellSize;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  /// GridData'ya göre yerleşmiş blokları render eder
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final gridData = gameRef.gridData;

    // Tüm grid hücrelerini kontrol et
    for (var x = 0; x < gridWidth; x++) {
      for (var y = 0; y < gridHeight; y++) {
        final cell = gridData.getCell(x, y);

        // Hücre doluysa bloğu çiz
        if (cell.state == CellState.filled && cell.color != null) {
          final rect = Rect.fromLTWH(
            x * cellSize,
            y * cellSize,
            cellSize,
            cellSize,
          );

          // Bloğu çiz
          canvas
            ..drawRect(
              rect,
              Paint()..color = cell.color!,
            )

            // Kenarlık çiz (opsiyonel)
            ..drawRect(
              rect,
              Paint()
                ..color = Colors.white.withOpacity(0.3)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
        }
      }
    }
  }
}
