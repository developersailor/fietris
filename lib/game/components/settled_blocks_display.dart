import 'package:fietris/game/grid_data.dart'; // GridData ve CellState'i import et
import 'package:flame/components.dart';
import 'package:flutter/material.dart'; // Canvas, Rect, Paint, Color için

class SettledBlocksDisplay extends PositionComponent {
  SettledBlocksDisplay({
    required this.gridData,
    required this.cellSize,
    required Vector2 position,
  }) : super(
          position: position,
          // Boyutu grid'in piksel boyutuyla eşleştir
          size: Vector2(gridWidth * cellSize, gridHeight * cellSize),
        );
  final GridData gridData;
  final double cellSize;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint(); // Tekrar tekrar oluşturmamak için dışarı alındı

    for (var y = 0; y < gridHeight; y++) {
      for (var x = 0; x < gridWidth; x++) {
        final cell = gridData.getCell(x, y);

        if (cell.state == CellState.filled && cell.color != null) {
          // Hücrenin component içindeki pozisyonu
          final rect = Rect.fromLTWH(
            x * cellSize, // Component'in (0,0)'ına göre X
            y * cellSize, // Component'in (0,0)'ına göre Y
            cellSize,
            cellSize,
          );
          paint.color = cell.color!; // Rengi ayarla
          canvas
            ..drawRect(rect, paint)

            // Kenarlık çiz (opsiyonel - daha belirgin görünmesi için)
            ..drawRect(
              rect,
              Paint()
                ..color = Colors.white.withAlpha((255 * 0.3).round())
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
        }
      }
    }
  }
}
