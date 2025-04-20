import 'package:fietris/game/blocks/block_type.dart';
import 'package:fietris/game/fietris_game.dart'; // FietrisGame sınıfını import et
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Block extends PositionComponent with HasGameRef<FietrisGame> {
  // Bloğun mevcut şekil offsetlerini tutar

  Block({
    required this.blockType,
    required this.cellSize,
    required Vector2 initialPosition,
  })  : color = blockType.color,
        currentShapeOffsets =
            List.from(blockType.shape), // Başlangıçta ana şekli kopyala
        super(position: initialPosition);
  final BlockType blockType;
  final double cellSize;
  final Color color;
  // int rotationState = 0; // Dönme durumu için (sonraki adımlarda)

  final List<PositionComponent> _blockPieces = [];
  List<Vector2> currentShapeOffsets;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildBlock();
  }

  void _buildBlock() {
    removeAll(_blockPieces);
    _blockPieces.clear();

    for (final partOffset in currentShapeOffsets) {
      final piece = RectangleComponent(
        position: Vector2(partOffset.x * cellSize, partOffset.y * cellSize),
        size: Vector2.all(cellSize),
        paint: Paint()..color = color,
      );
      _blockPieces.add(piece);
      add(piece);
    }
    // İstenirse boyut ayarlanabilir
    // size = ...
  }

  void moveDown() {
    position.y += cellSize;
  }

  void moveLeft() {
    position.x -= cellSize;
  }

  void moveRight() {
    position.x += cellSize;
  }

  void moveUp() {
    position.y -= cellSize;
  }

  void rotate() {
    // Döndürme mantığını doğrudan çağırmak yerine
    // try metodu ile döndürme işlemini dene
    tryRotate();
  }

  /// Bloğu saat yönünde döndürmeyi dener.
  /// Başarılı olursa true, olmazsa false döndürür.
  bool tryRotate() {
    // 1. Potansiyel yeni şekil offsetlerini hesapla (saat yönü: x,y -> -y,x)
    final rotatedOffsets = currentShapeOffsets.map((offset) {
      // Pivot noktası (0,0) etrafında 90 derece saat yönü döndürme
      return Vector2(-offset.y, offset.x);
    }).toList();

    // 2. Başlangıç çarpışma kontrolü (aynı pozisyonda, yeni şekille)
    if (!gameRef.checkCollision(
      this,
      position,
      blockShapeOffsets: rotatedOffsets,
    )) {
      // Çarpışma yok, döndürmeyi uygula
      currentShapeOffsets = rotatedOffsets;
      _buildBlock(); // Görseli güncelle
      return true;
    }

    // 3. Basit Wall Kick Denemeleri (Opsiyonel ama önerilir)
    // Sadece 1 birim sola ve 1 birim sağa deneyelim
    final kickOffsets = <Vector2>[
      Vector2(-cellSize, 0), // Sola itme
      Vector2(cellSize, 0), // Sağa itme
      // (yukarı/aşağı, 2 birim vs.)
    ];

    for (final kick in kickOffsets) {
      final potentialPosition = position + kick; // İtilmiş potansiyel pozisyon
      if (!gameRef.checkCollision(
        this,
        potentialPosition,
        blockShapeOffsets: rotatedOffsets,
      )) {
        // Bu kick pozisyonunda çarpışma yok, döndürmeyi ve itmeyi uygula
        position = potentialPosition; // Pozisyonu güncelle (itme)
        currentShapeOffsets = rotatedOffsets; // Şekli güncelle (dönme)
        _buildBlock(); // Görseli güncelle
        return true;
      }
    }
    // 4. Hiçbir pozisyon uygun değilse
    return false; // Döndürme başarısız
  }
}
