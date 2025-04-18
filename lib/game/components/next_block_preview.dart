import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../blocks/block_type.dart';

class NextBlockPreview extends PositionComponent {
  final double areaSize;
  final double mainCellSize;
  late final double previewCellSize;
  late final Vector2 blockAreaOrigin;

  BlockType? _currentPreviewType;
  final List<RectangleComponent> _blockPieces = [];

  NextBlockPreview({
    required this.areaSize,
    required this.mainCellSize,
    required Vector2 position,
  }) : super(position: position, size: Vector2.all(areaSize)) {
    previewCellSize = mainCellSize * 0.5;
    blockAreaOrigin = size / 2;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.black.withOpacity(0.3),
    ));
  }

  void showBlock(BlockType? blockType) {
    _currentPreviewType = blockType;
    removeAll(_blockPieces);
    _blockPieces.clear();

    if (blockType != null) {
      final paint = Paint()..color = blockType.color;
      for (var offset in blockType.shape) {
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
