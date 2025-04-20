import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GridBackground extends PositionComponent {

  GridBackground({
    required this.gridWidth,
    required this.gridHeight,
    required this.cellSize,
    super.position,
  }) : super(size: Vector2(gridWidth * cellSize, gridHeight * cellSize));
  final int gridWidth;
  final int gridHeight;
  final double cellSize;
  final Paint linePaint = Paint()
    ..color = Colors.grey.withOpacity(0.5)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Dikey çizgiler
    for (var x = 0; x <= gridWidth; x++) {
      final dx = x * cellSize;
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx, gridHeight * cellSize),
        linePaint,
      );
    }
    // Yatay çizgiler
    for (var y = 0; y <= gridHeight; y++) {
      final dy = y * cellSize;
      canvas.drawLine(
        Offset(0, dy),
        Offset(gridWidth * cellSize, dy),
        linePaint,
      );
    }
  }
}
