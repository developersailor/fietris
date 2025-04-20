import 'dart:collection'; // Queue için
import 'dart:math';

import 'package:fietris/game/blocks/block.dart';
import 'package:fietris/game/blocks/block_type.dart';
import 'package:fietris/game/components/next_block_preview.dart';
import 'package:fietris/game/components/settled_blocks_component.dart';
import 'package:fietris/game/grid_background.dart';
import 'package:fietris/game/grid_config.dart';
import 'package:fietris/game/grid_data.dart';
import 'package:flame/components.dart'
    hide Block; // TextComponent için, Block hariç
// RemoveEffect için
import 'package:flame/events.dart'; // KeyboardEvents için
import 'package:flame/game.dart';
// Particle, ParticleSystemComponent için
import 'package:flame/text.dart'; // TextPaint için
import 'package:flutter/material.dart' show Colors, Offset, Shadow, TextStyle;
import 'package:flutter/services.dart'; // LogicalKeyboardKey için
import 'package:flutter/widgets.dart'; // KeyEventResult için

// Oyun durumları
enum GameState { playing, gameOver, paused }

class FietrisGame extends FlameGame with KeyboardEvents, TapCallbacks {
  late GridData gridData;
  Block? currentBlock; // Şu an düşmekte olan blok
  Vector2 gridOrigin = Vector2(50, 50); // GridBackground ile aynı pozisyon
  late SettledBlocksComponent
      settledBlocksComponent; // Yerleşen blokları gösterecek component
  BlockType? nextBlockType; // Sonraki blok tipi
  late NextBlockPreview nextBlockPreviewComponent; // Önizleme component'i

  int score = 0; // Oyuncu skoru
  late TextComponent scoreTextComponent;
  late final TextPaint scoreTextPaint;

  // Seviye sistemi değişkenleri
  int currentLevel = 1; // Mevcut oyun seviyesi
  int linesClearedTotal =
      0; // Oyun başından beri temizlenen toplam satır sayısı
  int linesPerLevel = 10; // Seviye atlamak için gereken satır sayısı
  late TextComponent levelTextComponent; // Seviye gösterge bileşeni

  // Game Over UI için
  late TextComponent gameOverTextComponent;

  // Oyun durumu
  GameState currentState = GameState.playing; // Başlangıç durumu

  double fallInterval = 1; // Her bir adım için saniye cinsinden süre
  double timeSinceLastFall = 0; // Son düşme adımından beri geçen süre

  bool isProcessingMatches = false; // Eşleşme/Yerçekimi zinciri işleniyor mu?
  int comboMultiplier = 0; // Mevcut kombo çarpanı/seviyesi

  late TextComponent comboTextComponent;
  late final TextPaint comboTextPaint;

  static const int fitBonusPoints = 50; // Mükemmel Uyum bonus puanı

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    gridData = GridData();

    // GridBackground ekle
    final gridBg = GridBackground(
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      cellSize: defaultCellSize,
      position: gridOrigin,
    );
    add(gridBg);

    // Yerleşen blokları gösteren component'i ekle
    settledBlocksComponent = SettledBlocksComponent(
      cellSize: defaultCellSize,
      position: gridOrigin,
    );
    add(settledBlocksComponent);

    // Skor metni stilini tanımla
    scoreTextPaint = TextPaint(
      style: const TextStyle(
        fontSize: 24,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: [
          // Okunabilirliği artırmak için gölge
          Shadow(
            blurRadius: 1,
            color: Color.fromRGBO(0, 0, 0, 0.5),
            offset: Offset(1, 1),
          ),
        ],
      ),
    );

    // Skor TextComponent'ini oluştur ve ekle
    scoreTextComponent = TextComponent(
      text: 'Score: $score', // Başlangıç skoru
      textRenderer: scoreTextPaint,
      position: Vector2(
        gridOrigin.x,
        gridOrigin.y - 30,
      ), // Grid'in biraz üstüne konumlandır
      anchor: Anchor.topLeft,
    );
    add(scoreTextComponent); // Component'i oyuna ekle

    // Seviye göstergesini oluştur ve ekle
    levelTextComponent = TextComponent(
      text: 'Level: $currentLevel',
      textRenderer: scoreTextPaint,
      position: Vector2(
        scoreTextComponent.position.x,
        scoreTextComponent.position.y + 30,
      ), // Skorun altına
      anchor: Anchor.topLeft,
    );
    add(levelTextComponent);

    // Başlangıç düşme aralığını seviyeye göre ayarla
    fallInterval = calculateFallIntervalForLevel(currentLevel);

    // Önizleme component'ini oluştur
    const previewAreaSize = defaultCellSize * 4;
    nextBlockPreviewComponent = NextBlockPreview(
      areaSize: previewAreaSize,
      mainCellSize: defaultCellSize,
      position: Vector2(
        scoreTextComponent.position.x + scoreTextComponent.width + 20,
        scoreTextComponent.position.y,
      ),
    );
    add(nextBlockPreviewComponent);

    // "Next" etiketi ekle
    add(
      TextComponent(
        text: 'Next:',
        textRenderer: scoreTextPaint,
        position: nextBlockPreviewComponent.position + Vector2(0, -20),
      ),
    );

    // Game Over metni stilini tanımla
    final gameOverTextPaint = TextPaint(
      style: const TextStyle(
        fontSize: 48, // Daha büyük font
        color: Colors.red, // Dikkat çekici renk
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 2,
            color: Color.fromRGBO(0, 0, 0, 0.7),
            offset: Offset(2, 2),
          ),
        ],
      ),
    );

    // Game Over TextComponent'ini oluştur (başlangıçta boş)
    gameOverTextComponent = TextComponent(
      text: '', // Başlangıçta boş
      textRenderer: gameOverTextPaint,
      position: size / 2, // Ekranın ortasına konumlandır
      anchor: Anchor.center, // Ortaya hizala
    );
    add(gameOverTextComponent); // Oyuna ekle

    // Kombo metni stilini tanımla
    comboTextPaint = TextPaint(
      style: const TextStyle(
        fontSize: 32,
        color: Colors.yellowAccent,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 2,
            color: Color.fromRGBO(0, 0, 0, 0.7),
            offset: Offset(2, 2),
          ),
        ],
      ),
    );

    // Kombo TextComponent'ini oluştur
    comboTextComponent = TextComponent(
      text: '',
      textRenderer: comboTextPaint,
      position: Vector2(size.x / 2, size.y * 0.75),
      anchor: Anchor.center,
    );
    add(comboTextComponent);

    // NOT: Eski dokunmatik kontroller overlay ile değiştirildiği
    //      için devre dışı bırakıldı
    // await add(TouchControls(game: this));
    // print('Touch controls added!');

    // İlk bloğu oluştur ve ekle
    spawnNewBlock();
  }

  void spawnNewBlock() {
    if (currentState == GameState.gameOver) {
      return; // Zaten bittiyse yeni blok oluşturma
    }

    BlockType typeToSpawn;

    if (nextBlockType == null) {
      typeToSpawn = BlockType.getRandom();
      nextBlockType = BlockType.getRandom();
    } else {
      typeToSpawn = nextBlockType!;
      nextBlockType = BlockType.getRandom();
    }

    const startX = gridWidth ~/ 2;
    const startY = 0;

    // === DÜZELTME: Spawn Alanı Kontrolü ===
    // Blok oluşturmadan önce, yerleşeceği grid hücreleri dolu mu diye bak
    for (final pieceOffset in typeToSpawn.shape) {
      // Parçanın potansiyel grid koordinatı (spawn pozisyonuna göre)
      final targetGridX = startX + pieceOffset.x.toInt();
      final targetGridY = startY + pieceOffset.y.toInt();

      // Grid içinde mi (X ekseni kontrolü)
      if (targetGridX < 0 || targetGridX >= gridWidth) {
        // X ekseni dışında - bu normal değil, blok oluşturulamaz
        gameOver();
        return;
      }

      // Bu hücre dolu mu?
      if (gridData.getCell(targetGridX, targetGridY).state ==
          CellState.filled) {
        // Bu hücre zaten doluysa oyun biter
        gameOver();
        return;
      }
    }
    // ===============================

    final spawnPosition = Vector2(
      gridOrigin.x + startX * defaultCellSize,
      gridOrigin.y + startY * defaultCellSize,
    );
    currentBlock = Block(
      blockType: typeToSpawn,
      cellSize: defaultCellSize,
      initialPosition: spawnPosition,
    );
    add(currentBlock!);

    // Önizlemeyi güncelle
    updateNextBlockPreview();
  }

  void updateNextBlockPreview() {
    if (nextBlockPreviewComponent.isMounted) {
      nextBlockPreviewComponent.showBlock(nextBlockType);
    }
  }

  @override
  void update(double dt) {
    if (currentState == GameState.gameOver || isProcessingMatches) return;

    super.update(dt); // Önce üst sınıfın update'ini çağır

    // Eğer düşen bir blok yoksa işlem yapma
    if (currentBlock == null) {
      return;
    }

    // Zamanlayıcıyı güncelle
    timeSinceLastFall += dt;

    // Belirlenen aralık geçti mi?
    if (timeSinceLastFall >= fallInterval) {
      // Zamanlayıcıyı sıfırla (taşan süreyi koru)
      timeSinceLastFall -= fallInterval;

      // ÖNCE hareket et, SONRA kontrol et (POST-CHECK yaklaşımı)
      currentBlock!.moveDown(); // Bloğu aşağı taşı

      // Yeni pozisyonda çarpışma var mı?
      if (checkCollision(currentBlock!, currentBlock!.position)) {
        // Evet, çarpışma var - hareketi geri al
        currentBlock!.moveUp();

        // Bloğu yerleştir
        settleBlock();
        return;
      }
    }

    // Diğer oyun mantığı güncellemeleri (varsa)
  }

  // Dünya (ekran) pozisyonunu grid koordinatlarına çevirir
  Vector2 worldToGridCoords(Vector2 worldPos) {
    final gridX = ((worldPos.x - gridOrigin.x) / defaultCellSize).floor();
    final gridY = ((worldPos.y - gridOrigin.y) / defaultCellSize).floor();
    return Vector2(gridX.toDouble(), gridY.toDouble());
  }

  // Grid koordinatlarını dünya (ekran) pozisyonuna çevirir (sol üst köşe)
  Vector2 gridToWorldCoords(int gridX, int gridY) {
    final worldX = gridOrigin.x + gridX * defaultCellSize;
    final worldY = gridOrigin.y + gridY * defaultCellSize;
    return Vector2(worldX, worldY);
  }

  /// Verilen bloğun, belirtilen `worldPosition`'da
  /// herhangi bir yere çarpıp çarpmadığını kontrol eder.
  /// `blockShapeOffsets`: Bloğun kendi içindeki parçalarının
  ///  pivot noktasına göre göreceli grid offsetleri.
  ///                   Eğer null ise, `block.blockType.shape` kullanılır.
  /// Dönme kontrolü için override edilebilir.
  bool checkCollision(
    Block block,
    Vector2 worldPosition, {
    List<Vector2>? blockShapeOffsets,
  }) {
    final shape = blockShapeOffsets ??
        block.blockType.shape; // Kullanılacak şekil offsetleri

    for (final pieceOffset in shape) {
      // 1. Parçanın potansiyel mutlak dünya koordinatını hesapla
      final pieceWorldPos = Vector2(
        worldPosition.x + pieceOffset.x * block.cellSize,
        worldPosition.y + pieceOffset.y * block.cellSize,
      );

      // 2. Parçanın potansiyel grid koordinatlarını hesapla
      final gridCoords = worldToGridCoords(pieceWorldPos);
      final gridX = gridCoords.x.toInt();
      final gridY = gridCoords.y.toInt();

      // 3. Sınır Kontrolleri
      // Sol Sınır
      if (gridX < 0) {
        return true;
      }
      // Sağ Sınır
      if (gridX >= gridWidth) {
        // grid_data.dart'tan gelen sabit
        return true;
      }
      // Alt Sınır
      if (gridY >= gridHeight) {
        // grid_data.dart'tan gelen sabit
        return true;
      }

      // 4. Yerleşmiş Blok Kontrolü
      // Grid içinde mi diye bakmaya gerek yok, zaten sınırlar kontrol edildi.
      // Ama gridY negatifse (yukarıda) kontrol etmeyebiliriz.
      if (gridY >= 0) {
        // Grid verisine eriş (gridData örneği FietrisGame içinde olmalı)
        final cell = gridData.getCell(gridX, gridY);
        if (cell.state == CellState.filled) {
          return true; // Yerleşmiş bloğa çarptı
        }
      }
    }

    // Yukarıdaki kontrollerden hiçbiri true döndürmediyse, çarpışma yok.
    return false;
  }

  /// Verilen blok parçası koordinatlarına göre "Mükemmel Uyum" olup
  /// olmadığını kontrol eder.
  /// Kontrol: Altında ve bloğun kapladığı satırlardaki
  /// yanlarında boşluk var mı?
  bool checkForFitBonus(List<Vector2> blockCoords) {
    if (blockCoords.isEmpty) return false;

    // 1. Alt Kontrolü: Bloğun her parçasının altı dolu veya sınır olmalı.
    for (final coord in blockCoords) {
      final currentX = coord.x.toInt();
      final belowY = coord.y.toInt() + 1;

      // Eğer alt sınır içinde mi?
      if (belowY < gridHeight) {
        // Altındaki hücre boş mu?
        if (gridData.getCell(currentX, belowY).state == CellState.empty) {
          return false; // Altında boşluk var, fit değil.
        }
      }
      // Sınır dışıysa (en alt sıra) sorun yok.
    }

    // 2. Yan Kontrolü: Bloğun kapladığı her satır seviyesinde, en soldaki
    //    parçanın solu ve en sağdaki parçanın sağı dolu veya sınır olmalı.
    final yLevelBounds = <int, Map<String, int>>{};
    for (final coord in blockCoords) {
      final y = coord.y.toInt();
      final x = coord.x.toInt();
      if (yLevelBounds.containsKey(y)) {
        if (x < yLevelBounds[y]!['minX']!) yLevelBounds[y]!['minX'] = x;
        if (x > yLevelBounds[y]!['maxX']!) yLevelBounds[y]!['maxX'] = x;
      } else {
        yLevelBounds[y] = {'minX': x, 'maxX': x};
      }
    }

    for (final yLevel in yLevelBounds.keys) {
      final bounds = yLevelBounds[yLevel]!;
      // Sol kontrolü
      final leftX = bounds['minX']! - 1;
      if (leftX >= 0) {
        // Sol sınır içinde mi?
        if (gridData.getCell(leftX, yLevel).state == CellState.empty) {
          return false; // Solunda boşluk var, fit değil.
        }
      }
      // Sağ kontrolü
      final rightX = bounds['maxX']! + 1;
      if (rightX < gridWidth) {
        // Sağ sınır içinde mi?
        if (gridData.getCell(rightX, yLevel).state == CellState.empty) {
          return false; // Sağında boşluk var, fit değil.
        }
      }
    }

    // Tüm kontrollerden geçtiyse, mükemmel uyum!
    return true;
  }

  /// Düşen bloğu grid'e yerleştirir ve yeni bir blok oluşturur
  void settleBlock() {
    if (currentBlock == null) return;

    final settledBlock = currentBlock!;
    final currentOffsets = settledBlock.currentShapeOffsets;
    final blockColor = settledBlock.color;
    final Vector2 blockWorldPos = settledBlock.position;
    final cellSz = settledBlock.cellSize;

    // Geçici: Blok parçalarının grid koordinatlarını sakla
    final blockPieceGridCoords = <Vector2>[];

    // 1. Grid Verisini Güncelle ve Koordinatları Topla
    for (final pieceOffset in currentOffsets) {
      final pieceWorldPos = Vector2(
        blockWorldPos.x + pieceOffset.x * cellSz,
        blockWorldPos.y + pieceOffset.y * cellSz,
      );
      final gridCoords = worldToGridCoords(pieceWorldPos);
      final gridX = gridCoords.x.toInt();
      final gridY = gridCoords.y.toInt();
      blockPieceGridCoords.add(Vector2(gridX.toDouble(), gridY.toDouble()));

      // === YENİ: Tavan Kontrolü ===
      if (gridY < 0) {
        gameOver();
        return;
      }
      // =========================

      if (gridData.isWithinBounds(gridX, gridY)) {
        gridData.setCell(gridX, gridY, CellState.filled, blockColor);
      } else {}
    }

    // === YENİ: Fit Bonusu Kontrolü ===
    final isFit = checkForFitBonus(blockPieceGridCoords);
    if (isFit) {
      score += fitBonusPoints;
      updateScoreDisplay();
    }
    // ==============================

    // 2. Düşen Blok Component'ini Kaldır
    remove(currentBlock!);

    // 3. Mevcut Blok Referansını Temizle
    currentBlock = null;

    // 4. Görsel Güncelleme
    // (artık SettledBlocksComponent tarafından otomatik yapılıyor)

    // === YENİ: Otomatik Alan Kontrolü ===
    final potentialAutoClearAreas = checkPotentialAutoClearAreas();
    if (potentialAutoClearAreas.isNotEmpty) {
      // === YENİ: Otomatik Alan Temizlemeyi Tetikle ===
      performAutoAreaClear(potentialAutoClearAreas);
      return; // Otomatik temizleme yapılırsa diğer kontrolleri atla
      // =============================================
    }
    // ===================================

    // 5. Tamamlanan Sıraları Kontrol Et ve Temizle
    checkForCompletedLines();

    // 6. Yeni Blok Oluştur
    if (!isProcessingMatches) {
      spawnNewBlock();
    }
  }

  /// Tüm sıraları kontrol eder ve tamamlananları temizler
  void checkForCompletedLines() {
    final completedLines = <int>[]; // Tamamlanan satırların Y indekslerini tut

    // Satırları aşağıdan yukarıya doğru tara (yüksek Y'den düşüğe)
    for (var y = gridHeight - 1; y >= 0; y--) {
      var lineIsComplete = true;
      // Satırdaki her hücreyi kontrol et
      for (var x = 0; x < gridWidth; x++) {
        if (gridData.getCell(x, y).state != CellState.filled) {
          lineIsComplete = false; // Bir hücre bile boşsa satır tamamlanmamıştır
          break; // Bu satırın kontrolünü bitir
        }
      }

      // Eğer satır tamamsa listeye ekle
      if (lineIsComplete) {
        completedLines.add(y);
      }
    }

    // Eğer tamamlanan satır(lar) varsa temizleme ve kaydırma işlemini başlat
    if (completedLines.isNotEmpty) {
      // Skorlama - temizlenen satır sayısına göre puan ekle
      final linesCleared = completedLines.length;
      var pointsEarned = 0;

      switch (linesCleared) {
        case 1:
          pointsEarned = 100; // Tekli
        case 2:
          pointsEarned = 300; // İkili
        case 3:
          pointsEarned = 500; // Üçlü
        case 4:
          pointsEarned = 800; // Dörtlü (Fietris!)
        default: // 4'ten fazla (mümkünse?)
          pointsEarned = 1000;
      }
      score += pointsEarned; // Skoru güncelle
      updateScoreDisplay(); // Skor göstergesini güncelle

      // Satırları temizle ve üsttekileri kaydır
      clearAndShiftLines(completedLines);
    }
  }

  /// Belirli satırları temizler ve üstündeki tüm satırları aşağı kaydırır
  void clearAndShiftLines(List<int> linesToClear) {
    // Temizlenecek satırları küçükten büyüğe sırala
    //(kaydırmanın doğru çalışması için önemli)
    linesToClear.sort();
    final numLinesCleared =
        linesToClear.length; // Bu adımda temizlenen satır sayısı

    // Temizlenecek her satır için işlem yap
    for (final clearedY in linesToClear) {
      // Bu temizlenen satırın üzerindeki tüm satırları (aşağıdan yukarıya) işle
      for (var y = clearedY; y > 0; y--) {
        // y-1 satırındaki hücreleri y satırına kopyala
        for (var x = 0; x < gridWidth; x++) {
          final cellAbove = gridData.getCell(x, y - 1);
          gridData.setCell(x, y, cellAbove.state, cellAbove.color);
        }
      }

      // En üstteki satırı (y=0) temizle, çünkü artık boş olmalı
      for (var x = 0; x < gridWidth; x++) {
        gridData.setCell(x, 0, CellState.empty, null);
      }
    }

    // Toplam temizlenen satır sayısını güncelle
    linesClearedTotal += numLinesCleared;

    // Seviye Atlama Kontrolü
    // Gerekli satır sayısına ulaşıldı mı?
    //(Döngü ile birden fazla seviye atlanabilir)
    while (linesClearedTotal >= currentLevel * linesPerLevel) {
      levelUp();
    }

    // Görsel güncelleme otomatik olarak SettledBlocksComponent.
    // render içinde gerçekleşmeli
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (currentState == GameState.gameOver || isProcessingMatches) {
      return KeyEventResult.ignored;
    }

    // Oyun bittiğindeyse SADECE yeniden başlatma tuşunu dinle
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR) {
      restartGame(); // Yeniden başlatma metodunu çağır
      return KeyEventResult.handled;
    }

    // Sadece tuşa basılma anını dinle
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Düşen blok var mı kontrol et
      if (currentBlock == null) {
        return KeyEventResult.ignored; // Blok yoksa olayı yoksay
      }

      Vector2? potentialPosition; // Potansiyel yeni pozisyonu tutacak değişken

      // Sol Ok Tuşu
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Potansiyel yeni pozisyonu hesapla (bir hücre sola)
        potentialPosition = Vector2(
          currentBlock!.position.x - currentBlock!.cellSize,
          currentBlock!.position.y,
        );
        // Çarpışma kontrolü yap
        if (!checkCollision(currentBlock!, potentialPosition)) {
          // Çarpışma yoksa bloğu sola hareket ettir
          currentBlock!.moveLeft();
          return KeyEventResult.handled; // Olay işlendi
        } else {
          return KeyEventResult.handled; // Olay işlendi (hareket olmasa bile)
        }
      }
      // Sağ Ok Tuşu
      else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Potansiyel yeni pozisyonu hesapla (bir hücre sağa)
        potentialPosition = Vector2(
          currentBlock!.position.x + currentBlock!.cellSize,
          currentBlock!.position.y,
        );
        // Çarpışma kontrolü yap
        if (!checkCollision(currentBlock!, potentialPosition)) {
          // Çarpışma yoksa bloğu sağa hareket ettir
          currentBlock!.moveRight();
          return KeyEventResult.handled; // Olay işlendi
        } else {
          return KeyEventResult.handled; // Olay işlendi (hareket olmasa bile)
        }
      }
      // Yukarı Ok Tuşu (Döndürme)
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        currentBlock!.tryRotate(); // Döndürmeyi dene
        return KeyEventResult.handled;
      }
      // Aşağı Ok Tuşu (Yumuşak Hızlı Düşürme - Soft Drop)
      else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // 1. Potansiyel yeni pozisyonu hesapla (bir hücre aşağı)
        potentialPosition = Vector2(
          currentBlock!.position.x,
          currentBlock!.position.y + currentBlock!.cellSize,
        );

        // 2. Aşağıdaki pozisyon için çarpışma kontrolü yap
        if (!checkCollision(currentBlock!, potentialPosition)) {
          // 3. Çarpışma yoksa:
          // a. Bloğu aşağı hareket ettir
          currentBlock!.moveDown();
          // b. Otomatik düşme zamanlayıcısını
          // sıfırla (anında çift adım olmasın)
          timeSinceLastFall = 0.0;
          // c. Soft drop için küçük bir skor ekle
          score += 1; // Her başarılı soft drop adımı için 1 puan
          updateScoreDisplay(); // Skor göstergesini güncelle
          return KeyEventResult.handled; // Olay işlendi
        } else {
          // 4. Çarpışma varsa:
          // Hareket ettirme. Normal otomatik düşme mantığı bir sonraki
          // update döngüsünde çarpışmayı algılayıp
          // yerleştirme işlemini tetikleyecek
          return KeyEventResult.handled; // Olay yine de işlendi (tuşa basıldı)
        }
      }
      // Boşluk Tuşu (Hard Drop)
      else if (event.logicalKey == LogicalKeyboardKey.space) {
        performHardDrop(); // Hard drop işlemini yap
        return KeyEventResult.handled;
      }
    }
    // Diğer tuşları veya olayları yoksay
    return KeyEventResult.ignored;
  }

  // Skor göstergesini güncelleyen yardımcı metot
  void updateScoreDisplay() {
    if (scoreTextComponent.isMounted) {
      scoreTextComponent.text = 'Score: $score';
    }
  }

  /// Oyunu sonlandırır ve "Game Over" ekranını gösterir
  void gameOver() {
    // Zaten oyun bittiyse tekrar tetikleme
    if (currentState == GameState.gameOver) return;

    currentState = GameState.gameOver;

    // Düşen bloğu hemen kaldırabilirsin (opsiyonel)
    // if (currentBlock != null) remove(currentBlock!);
    // currentBlock = null;

    // Game Over UI'ını göster
    if (gameOverTextComponent.isMounted) {
      // Component ekli mi kontrol et
      gameOverTextComponent.text = 'GAME OVER\nScore: $score';
    }

    // Oyun bitti ekranını göster
    showGameOverScreen();
  }

  /// Oyunu yeniden başlatır, tüm değişkenleri ve grid'i sıfırlar
  void restartGame() {
    // 1. Durum Değişkenlerini Sıfırla
    score = 0;
    currentState = GameState.playing;
    timeSinceLastFall = 0.0;

    // Seviye Sistemini Sıfırla
    currentLevel = 1;
    linesClearedTotal = 0;
    fallInterval =
        calculateFallIntervalForLevel(currentLevel); // Hızı Seviye 1'e ayarla
    updateLevelDisplay(); // UI'ı güncelle

    // 2. Grid Verisini Temizle
    gridData.clearGrid();

    // 3. Görselleri Temizle/Sıfırla
    if (currentBlock != null) {
      remove(currentBlock!);
      currentBlock = null;
    }

    // Game Over mesajını temizle
    if (gameOverTextComponent.isMounted) {
      gameOverTextComponent.text = '';
    }

    // 4. Skor Göstergesini Güncelle
    updateScoreDisplay();

    // 5. İlk Bloğu Oluştur
    spawnNewBlock();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // Oyun bittiğinde yeniden başlatma kontrolü
    if (currentState == GameState.gameOver) {
      restartGame();
      return;
    }

    // TÜM BLOK SİLME MANTIĞI KALDIRILDI
    // Artık hiçbir şekilde tıklama ile bloklar temizlenmiyor

    // Debug için bilgi mesajı

    // Bu metot artık sadece bilgi vermek için var, başka bir işlem yapmıyor.
    // Bloklar sadece otomatik temizleme sistemi ile temizlenecek
  }

  /// Verilen başlangıç noktasından başlayarak, hedef renkle eşleşen ve
  /// birbirine bağlı (4 yönlü) dolu hücrelerin grid koordinatlarını bulur.
  /// BFS algoritmasını kullanır.
  List<Vector2> findMatches(int startX, int startY, Color targetColor) {
    final matchedCells = <Vector2>[]; // Bulunan eşleşen hücreler
    final queue = Queue<Vector2>(); // Ziyaret edilecek hücreler kuyruğu
    final visited = <Vector2>{}; // Ziyaret edilen veya kuyruğa eklenen hücreler

    // Başlangıç hücresi geçerli mi?
    final startCell = gridData.getCell(startX, startY);
    if (startCell.state != CellState.filled || startCell.color != targetColor) {
      return matchedCells;
      // Başlangıç hücresi hedefle eşleşmiyorsa boş liste döndür
    }

    // BFS Başlangıcı
    final startVec = Vector2(startX.toDouble(), startY.toDouble());
    queue.add(startVec);
    visited.add(startVec);

    // Kuyruk boşalana kadar devam et
    while (queue.isNotEmpty) {
      final currentVec = queue.removeFirst();
      matchedCells.add(currentVec); // Eşleşenlere ekle

      final currentX = currentVec.x.toInt();
      final currentY = currentVec.y.toInt();

      // Komşuları kontrol et (Yukarı, Aşağı, Sol, Sağ)
      final neighborsOffsets = <Vector2>[
        Vector2(0, -1), // Yukarı
        Vector2(0, 1), // Aşağı
        Vector2(-1, 0), // Sol
        Vector2(1, 0), // Sağ
      ];

      for (final offset in neighborsOffsets) {
        final neighborX = currentX + offset.x.toInt();
        final neighborY = currentY + offset.y.toInt();
        final neighborVec = Vector2(neighborX.toDouble(), neighborY.toDouble());

        // 1. Sınır Kontrolü
        if (!gridData.isWithinBounds(neighborX, neighborY)) continue;

        // 2. Ziyaret Edildi mi Kontrolü
        if (visited.contains(neighborVec)) continue;

        // 3. Hücre Durumu ve Renk Kontrolü
        final neighborCell = gridData.getCell(neighborX, neighborY);
        if (neighborCell.state == CellState.filled &&
            neighborCell.color == targetColor) {
          // Eşleşme bulundu! Kuyruğa ve ziyaret edilenlere ekle
          visited.add(neighborVec);
          queue.add(neighborVec);
        }
      }
    }

    // Eşleşen hücrelerin listesini döndür
    return matchedCells;
  }

  // Sadece GridData'yı temizler
  void _clearMatchesInternal(List<Vector2> matches) {
    if (matches.isEmpty) return;
    for (final matchCoord in matches) {
      final gridX = matchCoord.x.toInt();
      final gridY = matchCoord.y.toInt();
      if (gridData.isWithinBounds(gridX, gridY)) {
        gridData.setCell(gridX, gridY, CellState.empty, null);
      }
    }
  }

  // Sadece GridData'ya yerçekimi uygular
  void _applyGravityInternal() {
    for (var x = 0; x < gridWidth; x++) {
      var writeIndex = gridHeight - 1;
      for (var y = gridHeight - 1; y >= 0; y--) {
        final cell = gridData.getCell(x, y);
        if (cell.state == CellState.filled) {
          if (y != writeIndex) {
            gridData
              ..setCell(x, writeIndex, cell.state, cell.color)
              ..setCell(x, y, CellState.empty, null);
          }
          writeIndex--;
        }
      }
    }
  }

  /// Tüm grid'i tarar ve 3 veya daha fazla eşleşen blok gruplarını bulur.
  List<Vector2> findNewCombos() {
    final allNewMatches = <Vector2>[];
    final visitedInCycle = <Vector2>{};

    for (var y = 0; y < gridHeight; y++) {
      for (var x = 0; x < gridWidth; x++) {
        final currentVec = Vector2(x.toDouble(), y.toDouble());
        if (!visitedInCycle.contains(currentVec)) {
          final cell = gridData.getCell(x, y);
          if (cell.state == CellState.filled && cell.color != null) {
            final potentialMatch = findMatches(x, y, cell.color!);
            visitedInCycle.addAll(potentialMatch);
            if (potentialMatch.length >= 3) {
              allNewMatches.addAll(potentialMatch);
            }
          } else {
            visitedInCycle.add(currentVec);
          }
        }
      }
    }
    return allNewMatches;
  }

  /// Temizlenen blok sayısına göre temel puanı hesaplar.
  int calculateMatchScore(int numberOfBlocks) {
    if (numberOfBlocks < 3) return 0;
    switch (numberOfBlocks) {
      case 3:
        return 30;
      case 4:
        return 50;
      case 5:
        return 80;
      default:
        return 80 + (numberOfBlocks - 5) * 40;
    }
  }

  void updateComboDisplay() {
    if (isMounted && children.contains(comboTextComponent)) {
      if (comboMultiplier >= 2) {
        comboTextComponent.text = 'Combo x$comboMultiplier!';
      } else {
        comboTextComponent.text = '';
      }
    }
  }

  void clearComboDisplay() {
    if (isMounted && children.contains(comboTextComponent)) {
      comboTextComponent.text = '';
    }
  }

  /// Verilen eşleşmeleri temizler, yerçekimi uygular ve yeni kombolar arar.
  void processMatchesAndGravity(List<Vector2> matchesToClear) {
    comboMultiplier++;

    final baseScore = calculateMatchScore(matchesToClear.length);
    final currentStepScore = baseScore * comboMultiplier;
    score += currentStepScore;
    updateScoreDisplay();

    updateComboDisplay();

    _clearMatchesInternal(matchesToClear);
    _applyGravityInternal();

    final nextMatches = findNewCombos();

    if (nextMatches.isNotEmpty) {
      processMatchesAndGravity(nextMatches);
    } else {
      isProcessingMatches = false;
      clearComboDisplay();
    }
  }

  /// Verilen seviyeye göre düşme aralığını (saniye) hesaplar.
  double calculateFallIntervalForLevel(int level) {
    // Her seviyede hızı %10 artır (aralığı azalt)
    final interval = 1.0 * pow(0.9, level - 1); // %10 hızlanma (yaklaşık)
    return max(0.08, interval); // Minimum 0.08 saniye aralık (ayarlanabilir)
  }

  /// Seviye atlama işlemlerini yapar
  void levelUp() {
    currentLevel++;
    fallInterval =
        calculateFallIntervalForLevel(currentLevel); // Yeni hızı hesapla
    updateLevelDisplay(); // Seviye UI'ını güncelle
  }

  /// Seviye göstergesini günceller
  void updateLevelDisplay() {
    if (isMounted && children.contains(levelTextComponent)) {
      levelTextComponent.text = 'Level: $currentLevel';
    }
  }

  /// Verilen bloğun mevcut konumundan başlayarak inebileceği en alt
  /// geçerli dünya (world) koordinatını döndürür.
  Vector2 predictLandingPosition(Block block) {
    Vector2 currentPos = block.position; // Mevcut pozisyondan başla
    var nextPos = currentPos;

    while (true) {
      // Bir sonraki potansiyel pozisyon (bir hücre aşağı)
      nextPos = currentPos + Vector2(0, block.cellSize);

      // Bir sonraki pozisyonda çarpışma var mı?
      final collision = checkCollision(block, nextPos);

      if (collision) {
        // Evet, çarpışma var. Demek ki en son geçerli pozisyon 'currentPos'.
        // Döngüden çık ve currentPos'u döndür.
        break;
      } else {
        // Çarpışma yok, bir adım aşağı inebiliriz.
        currentPos = nextPos;
      }
    }
    return currentPos; // Son geçerli pozisyon
  }

  /// Hard Drop işlemini gerçekleştir  -
  /// bloğu anında en alttaki uygun konuma indirir
  void performHardDrop() {
    if (currentBlock == null) return; // Güvenlik kontrolü

    // 1. İniş pozisyonunu tahmin et
    final landingPosition = predictLandingPosition(currentBlock!);

    // 2. Bloğu anında o pozisyona taşı
    currentBlock!.position = landingPosition;

    // 3. Bloğu hemen yerleştir
    // (GridData'yı güncelle, satır kontrolü yap, yeni blok oluştur)
    settleBlock(); // settleBlock zaten gerekli adımları (SFX dahil) yapmalı
  }

  /// Sol ok butonu için public metot - bloğu sola hareket ettirir
  void moveBlockLeft() {
    if (currentState != GameState.playing ||
        isProcessingMatches ||
        currentBlock == null) {
      return;
    }
    final potentialPosition = Vector2(
      currentBlock!.position.x - defaultCellSize,
      currentBlock!.position.y,
    );
    if (!checkCollision(currentBlock!, potentialPosition)) {
      currentBlock!.moveLeft();
    }
  }

  /// Sağ ok butonu için public metot - bloğu sağa hareket ettirir
  void moveBlockRight() {
    if (currentState != GameState.playing ||
        isProcessingMatches ||
        currentBlock == null) {
      return;
    }
    final potentialPosition = Vector2(
      currentBlock!.position.x + defaultCellSize,
      currentBlock!.position.y,
    );
    if (!checkCollision(currentBlock!, potentialPosition)) {
      currentBlock!.moveRight();
    }
  }

  /// Döndürme butonu için public metot - bloğu döndürür
  void rotateBlock() {
    if (currentState != GameState.playing ||
        isProcessingMatches ||
        currentBlock == null) {
      return;
    }
    currentBlock!.tryRotate();
  }

  /// Yumuşak düşürme butonu için public metot - bloğu bir adım aşağı indirir
  void softDropBlock() {
    if (currentState != GameState.playing ||
        isProcessingMatches ||
        currentBlock == null) {
      return;
    }
    final potentialPosition = Vector2(
      currentBlock!.position.x,
      currentBlock!.position.y + defaultCellSize,
    );
    if (!checkCollision(currentBlock!, potentialPosition)) {
      currentBlock!.moveDown();
      timeSinceLastFall = 0.0; // Otomatik düşmeyi resetle
      score += 1; // Soft drop skoru
      updateScoreDisplay();
    }
  }

  /// Grid'i tarayarak, 1 ile 5 arasında boş hücre içeren 3 satırlık
  /// potansiyel otomatik temizleme alanlarını bulan metot.
  /// Bulunan alanların başlangıç Y indekslerini içeren bir liste döndürür.
  List<int> checkPotentialAutoClearAreas() {
    final candidateAreaStartRows =
        <int>[]; // Koşulu sağlayan alanların başlangıç satırları

    // Olası başlangıç satırlarını tara
    // (en alttaki 3 satır için y = gridHeight - 3)
    for (var y = 0; y <= gridHeight - 3; y++) {
      var emptyCellCount = 0;

      // Mevcut 3 satırlık alanı (y, y+1, y+2) tara
      for (var checkY = y; checkY < y + 3 && y < gridHeight; checkY++) {
        for (var x = 0; x < gridWidth; x++) {
          if (gridData.getCell(x, checkY).state == CellState.empty) {
            emptyCellCount++;
          }
        }
      }

      // Koşulu kontrol et: Boş hücre sayısı 1 ile 5 arasında mı?
      if (emptyCellCount >= 1 && emptyCellCount <= 5) {
        candidateAreaStartRows.add(y);
      }
    }

    // Not: Üst üste binen alanlar olabilir (örn: y=5 ve y=6 başlayabilir).
    return candidateAreaStartRows;
  }

  /// Belirtilen başlangıç satırlarından oluşan 3'lü alanlardaki
  /// TÜM DOLU hücreleri GridData'dan temizler.
  void performAutoAreaClear(List<int> startRows) {
    if (startRows.isEmpty) return;
    isProcessingMatches = true;

    // 1. Temizlenecek Benzersiz Hücre Koordinatlarını Topla
    // (Overlap'leri engellemek için Set kullan)
    final cellsToClear = <Vector2>{};
    for (final startY in startRows) {
      // İlgili 3 satırı ve tüm sütunları tara
      for (var y = startY; y < startY + 3 && y < gridHeight; y++) {
        // gridHeight sınırını kontrol et
        for (var x = 0; x < gridWidth; x++) {
          // Sadece DOLU hücreleri temizlenecekler listesine ekle
          if (gridData.getCell(x, y).state == CellState.filled) {
            cellsToClear.add(Vector2(x.toDouble(), y.toDouble()));
          }
        }
      }
    }

    // Eğer temizlenecek hücre bulunduysa devam et
    if (cellsToClear.isNotEmpty) {
      // 2. Toplanan Benzersiz Hücreleri GridData'dan Temizle
      for (final coord in cellsToClear) {
        final gridX = coord.x.toInt();
        final gridY = coord.y.toInt();
        // GridData'daki hücreyi temizle
        gridData.setCell(gridX, gridY, CellState.empty, null);
      }
      // score += calculateAutoClearScore(cellsToClear.length);
      // updateScoreDisplay();

      // Yerçekimi uygula - Bu temizleme sonrası yerçekimi etkilerini uygula
      _applyGravityInternal();
    } else {}

    // İşlem tamamlandı
    isProcessingMatches = false;

    // Yeni blok oluştur (eğer yoksa)
    if (currentBlock == null) {
      spawnNewBlock();
    }
  }

  /// Oyunu duraklatır ve duraklatma ekranını gösterir
  void pauseGame() {
    if (currentState == GameState.playing) {
      currentState = GameState.paused;
      // Duraklatma ekranını göster
      overlays.add('pauseScreen');
    }
  }

  /// Oyunu devam ettirir ve duraklatma ekranını kapatır
  void resumeGame() {
    if (currentState == GameState.paused) {
      currentState = GameState.playing;
      // Duraklatma ekranını kapat
      overlays.remove('pauseScreen');
    }
  }

  /// Oyun bittiğinde oyun bitti ekranını gösterir
  void showGameOverScreen() {
    if (currentState == GameState.gameOver) {
      // Oyun bitti ekranını göster
      overlays.add('gameOverScreen');
    }
  }

  /// Skor ekranını gösterir
  void showScoreboardScreen() {
    // Skor ekranını göster
    overlays.add('scoreboardScreen');
  }
}
