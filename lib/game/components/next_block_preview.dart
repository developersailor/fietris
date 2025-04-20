import 'package:fietris/game/blocks/block_type.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class NextBlockPreview extends PositionComponent {
  NextBlockPreview({
    required this.areaSize,
    required this.mainCellSize,
    required Vector2 position,
  }) : super(position: position, size: Vector2.all(areaSize)) {
    previewCellSize = mainCellSize * 0.5;
    blockAreaOrigin = size / 2;
  }
  final double areaSize;
  final double mainCellSize;
  late final double previewCellSize;
  late final Vector2 blockAreaOrigin;

  final List<RectangleComponent> _blockPieces = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = Colors.black.withAlpha((255 * 0.3).round()),
      ),
    );
  }

  void showBlock(BlockType? blockType) {
    removeAll(_blockPieces);
    _blockPieces.clear();

    if (blockType != null) {
      final paint = Paint()..color = blockType.color;
      for (final offset in blockType.shape) {
        final piece = RectangleComponent(
          position: blockAreaOrigin + offset * previewCellSize,
          size: Vector2.all(previewCellSize),
          paint: paint,
          anchor: Anchor.center,
        );
        _blockPieces.add(piece);
        add(piece);
      }
    }
  }
}
