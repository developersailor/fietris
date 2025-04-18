import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../fietris_game.dart';
import '../grid_data.dart';

/// Yerleşen blokları görselleştiren component
class SettledBlocksComponent extends PositionComponent
    with HasGameRef<FietrisGame> {
  final double cellSize;

  SettledBlocksComponent({
    required this.cellSize,
    required Vector2 position,
  }) : super(position: position);

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
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
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
