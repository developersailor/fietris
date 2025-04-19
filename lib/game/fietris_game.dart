import 'dart:collection'; // Queue için
import 'dart:math';

import 'package:fietris/game/blocks/block.dart';
import 'package:fietris/game/blocks/block_type.dart';
import 'package:fietris/game/components/next_block_preview.dart';
import 'package:fietris/game/components/settled_blocks_component.dart';
import 'package:fietris/game/components/touch_controls.dart';
import 'package:fietris/game/grid_background.dart';
import 'package:fietris/game/grid_config.dart';
import 'package:fietris/game/grid_data.dart';
import 'package:flame/components.dart'
    hide Block; // TextComponent için, Block hariç
import 'package:flame/effects.dart'; // RemoveEffect için
import 'package:flame/events.dart'; // KeyboardEvents için
import 'package:flame/game.dart';
import 'package:flame/particles.dart'; // Particle, ParticleSystemComponent için
import 'package:flame/text.dart'; // TextPaint için
import 'package:flutter/material.dart' show Colors, TextStyle, Shadow, Offset;
import 'package:flutter/services.dart'; // LogicalKeyboardKey için
import 'package:flutter/widgets.dart'; // KeyEventResult için

// Oyun durumları
enum GameState { playing, gameOver }

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

  double fallInterval = 1.0; // Her bir adım için saniye cinsinden süre
  double timeSinceLastFall = 0.0; // Son düşme adımından beri geçen süre

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
    print('GridBackground added!');

    // Yerleşen blokları gösteren component'i ekle
    settledBlocksComponent = SettledBlocksComponent(
      cellSize: defaultCellSize,
      position: gridOrigin,
    );
    add(settledBlocksComponent);
    print('SettledBlocksComponent added!');

    // Skor metni stilini tanımla
    scoreTextPaint = TextPaint(
      style: const TextStyle(
        fontSize: 24.0,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: [
          // Okunabilirliği artırmak için gölge
          Shadow(
              blurRadius: 1.0,
              color: Color.fromRGBO(0, 0, 0, 0.5),
              offset: Offset(1, 1)),
        ],
      ),
    );

    // Skor TextComponent'ini oluştur ve ekle
    scoreTextComponent = TextComponent(
      text: 'Score: $score', // Başlangıç skoru
      textRenderer: scoreTextPaint,
      position: Vector2(
          gridOrigin.x, gridOrigin.y - 30), // Grid'in biraz üstüne konumlandır
      anchor: Anchor.topLeft,
    );
    add(scoreTextComponent); // Component'i oyuna ekle
    print("Score display added.");

    // Seviye göstergesini oluştur ve ekle
    levelTextComponent = TextComponent(
      text: 'Level: $currentLevel',
      textRenderer: scoreTextPaint,
      position: Vector2(scoreTextComponent.position.x,
          scoreTextComponent.position.y + 30), // Skorun altına
      anchor: Anchor.topLeft,
    );
    add(levelTextComponent);
    print("Level display added.");

    // Başlangıç düşme aralığını seviyeye göre ayarla
    fallInterval = calculateFallIntervalForLevel(currentLevel);

    // Önizleme component'ini oluştur
    final previewAreaSize = defaultCellSize * 4;
    nextBlockPreviewComponent = NextBlockPreview(
      areaSize: previewAreaSize,
      mainCellSize: defaultCellSize,
      position: Vector2(
          scoreTextComponent.position.x + scoreTextComponent.width + 20,
          scoreTextComponent.position.y),
    );
    add(nextBlockPreviewComponent);

    // "Next" etiketi ekle
    add(TextComponent(
      text: 'Next:',
      textRenderer: scoreTextPaint,
      position: nextBlockPreviewComponent.position + Vector2(0, -20),
    ));

    // Game Over metni stilini tanımla
    final gameOverTextPaint = TextPaint(
      style: const TextStyle(
        fontSize: 48.0, // Daha büyük font
        color: Colors.red, // Dikkat çekici renk
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
              blurRadius: 2.0,
              color: Color.fromRGBO(0, 0, 0, 0.7),
              offset: Offset(2, 2))
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
    print("GameOver UI added.");

    // Kombo metni stilini tanımla
    comboTextPaint = TextPaint(
      style: const TextStyle(
        fontSize: 32.0,
        color: Colors.yellowAccent,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
              blurRadius: 2.0,
              color: Color.fromRGBO(0, 0, 0, 0.7),
              offset: Offset(2, 2))
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
    print("Combo display added.");

    // Dokunmatik kontrolleri ekle
    await add(TouchControls(game: this));
    print('Touch controls added!');

    // İlk bloğu oluştur ve ekle
    spawnNewBlock();
    print("Game loaded, first block spawned.");
  }

  void spawnNewBlock() {
    if (currentState == GameState.gameOver)
      return; // Zaten bittiyse yeni blok oluşturma

    BlockType typeToSpawn;

    if (nextBlockType == null) {
      typeToSpawn = BlockType.getRandom();
      nextBlockType = BlockType.getRandom();
      print("First spawn: Current=${typeToSpawn}, Next=${nextBlockType}");
    } else {
      typeToSpawn = nextBlockType!;
      nextBlockType = BlockType.getRandom();
      print("Spawning ${typeToSpawn}, Next is now ${nextBlockType}");
    }

    int startX = gridWidth ~/ 2;
    int startY = 0;

    // === DÜZELTME: Spawn Alanı Kontrolü ===
    // Blok oluşturmadan önce, yerleşeceği grid hücreleri dolu mu diye bak
    for (var pieceOffset in typeToSpawn.shape) {
      // Parçanın potansiyel grid koordinatı (spawn pozisyonuna göre)
      final targetGridX = startX + pieceOffset.x.toInt();
      final targetGridY = startY + pieceOffset.y.toInt();

      // Sadece grid içindeki ve görünür (y>=0) hücreleri kontrol et
      // Y<0 olması normaldir, bazı blokların başlangıçta bir kısmı ekran dışında olabilir
      if (targetGridY >= 0) {
        // Grid içinde mi (X ekseni kontrolü)
        if (targetGridX < 0 || targetGridX >= gridWidth) {
          // X ekseni dışında - bu normal değil, blok oluşturulamaz
          print(
              "GAME OVER: Block would spawn outside horizontal bounds at ($targetGridX, $targetGridY).");
          gameOver();
          return;
        }

        // Bu görünür hücre dolu mu?
        if (gridData.getCell(targetGridX, targetGridY).state ==
            CellState.filled) {
          // Bu hücre zaten doluysa oyun biter
          print(
              "GAME OVER: Cannot spawn block due to collision at ($targetGridX, $targetGridY).");
          gameOver();
          return;
        }
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
    print("Spawned new block: $typeToSpawn at $spawnPosition");

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

  @override
  void render(Canvas canvas) {
    super.render(canvas); // Önemli: Üst sınıfın render'ını çağırın
    // Oyun elemanlarının çizimleri buraya eklenecek
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

  /// Verilen bloğun, belirtilen `worldPosition`'da herhangi bir yere çarpıp çarpmadığını kontrol eder.
  /// `blockShapeOffsets`: Bloğun kendi içindeki parçalarının pivot noktasına göre göreceli grid offsetleri.
  ///                   Eğer null ise, `block.blockType.shape` kullanılır. Dönme kontrolü için override edilebilir.
  bool checkCollision(Block block, Vector2 worldPosition,
      {List<Vector2>? blockShapeOffsets}) {
    final shape = blockShapeOffsets ??
        block.blockType.shape; // Kullanılacak şekil offsetleri

    for (var pieceOffset in shape) {
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
        print("Collision: Left Boundary at ($gridX, $gridY)");
        return true;
      }
      // Sağ Sınır
      if (gridX >= gridWidth) {
        // grid_data.dart'tan gelen sabit
        print("Collision: Right Boundary at ($gridX, $gridY)");
        return true;
      }
      // Alt Sınır
      if (gridY >= gridHeight) {
        // grid_data.dart'tan gelen sabit
        print("Collision: Bottom Boundary at ($gridX, $gridY)");
        return true;
      }

      // 4. Yerleşmiş Blok Kontrolü
      // Grid içinde mi diye bakmaya gerek yok, zaten sınırlar kontrol edildi.
      // Ama gridY negatifse (yukarıda) kontrol etmeyebiliriz.
      if (gridY >= 0) {
        // Grid verisine eriş (gridData örneği FietrisGame içinde olmalı)
        final cell = gridData.getCell(gridX, gridY);
        if (cell.state == CellState.filled) {
          print("Collision: Filled Cell at ($gridX, $gridY)");
          return true; // Yerleşmiş bloğa çarptı
        }
      }
    }

    // Yukarıdaki kontrollerden hiçbiri true döndürmediyse, çarpışma yok.
    return false;
  }

  /// Verilen blok parçası koordinatlarına göre "Mükemmel Uyum" olup olmadığını kontrol eder.
  /// Kontrol: Altında ve bloğun kapladığı satırlardaki yanlarında boşluk var mı?
  bool checkForFitBonus(List<Vector2> blockCoords) {
    if (blockCoords.isEmpty) return false;

    // 1. Alt Kontrolü: Bloğun her parçasının altı dolu veya sınır olmalı.
    for (var coord in blockCoords) {
      final int currentX = coord.x.toInt();
      final int belowY = coord.y.toInt() + 1;

      // Eğer alt sınır içinde mi?
      if (belowY < gridHeight) {
        // Altındaki hücre boş mu?
        if (gridData.getCell(currentX, belowY).state == CellState.empty) {
          print("Fit check failed: Empty cell below at ($currentX, $belowY)");
          return false; // Altında boşluk var, fit değil.
        }
      }
      // Sınır dışıysa (en alt sıra) sorun yok.
    }

    // 2. Yan Kontrolü: Bloğun kapladığı her satır seviyesinde, en soldaki
    //    parçanın solu ve en sağdaki parçanın sağı dolu veya sınır olmalı.
    Map<int, Map<String, int>> yLevelBounds = {};
    for (var coord in blockCoords) {
      final y = coord.y.toInt();
      final x = coord.x.toInt();
      if (yLevelBounds.containsKey(y)) {
        if (x < yLevelBounds[y]!['minX']!) yLevelBounds[y]!['minX'] = x;
        if (x > yLevelBounds[y]!['maxX']!) yLevelBounds[y]!['maxX'] = x;
      } else {
        yLevelBounds[y] = {'minX': x, 'maxX': x};
      }
    }

    for (int yLevel in yLevelBounds.keys) {
      final bounds = yLevelBounds[yLevel]!;
      // Sol kontrolü
      final int leftX = bounds['minX']! - 1;
      if (leftX >= 0) {
        // Sol sınır içinde mi?
        if (gridData.getCell(leftX, yLevel).state == CellState.empty) {
          print("Fit check failed: Empty cell left at ($leftX, $yLevel)");
          return false; // Solunda boşluk var, fit değil.
        }
      }
      // Sağ kontrolü
      final int rightX = bounds['maxX']! + 1;
      if (rightX < gridWidth) {
        // Sağ sınır içinde mi?
        if (gridData.getCell(rightX, yLevel).state == CellState.empty) {
          print("Fit check failed: Empty cell right at ($rightX, $yLevel)");
          return false; // Sağında boşluk var, fit değil.
        }
      }
    }

    // Tüm kontrollerden geçtiyse, mükemmel uyum!
    print("Fit check passed!");
    return true;
  }

  /// Düşen bloğu grid'e yerleştirir ve yeni bir blok oluşturur
  void settleBlock() {
    if (currentBlock == null) return;
    print("Settling block: ${currentBlock!.blockType}");

    final Block settledBlock = currentBlock!;
    final List<Vector2> currentOffsets = settledBlock.currentShapeOffsets;
    final Color blockColor = settledBlock.color;
    final Vector2 blockWorldPos = settledBlock.position;
    final cellSz = settledBlock.cellSize;

    // Geçici: Blok parçalarının grid koordinatlarını sakla
    List<Vector2> blockPieceGridCoords = [];

    // 1. Grid Verisini Güncelle ve Koordinatları Topla
    for (var pieceOffset in currentOffsets) {
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
        print("GAME OVER: Block settled partially above ceiling at y=$gridY.");
        gameOver();
        return;
      }
      // =========================

      if (gridData.isWithinBounds(gridX, gridY)) {
        gridData.setCell(gridX, gridY, CellState.filled, blockColor);
        print(
            "Updated gridData at ($gridX, $gridY) to filled with $blockColor");
      } else {
        print(
            "Warning: Attempted to settle block piece outside bounds at ($gridX, $gridY)");
      }
    }

    // === YENİ: Fit Bonusu Kontrolü ===
    bool isFit = checkForFitBonus(blockPieceGridCoords);
    if (isFit) {
      print("FIT BONUS! +$fitBonusPoints points.");
      score += fitBonusPoints;
      updateScoreDisplay();
      // TODO: Fit Bonusu görsel/ses efekti tetikle
    }
    // ==============================

    // 2. Düşen Blok Component'ini Kaldır
    remove(currentBlock!);

    // 3. Mevcut Blok Referansını Temizle
    currentBlock = null;

    // 4. Görsel Güncelleme (artık SettledBlocksComponent tarafından otomatik yapılıyor)

    // 5. Tamamlanan Sıraları Kontrol Et ve Temizle
    checkForCompletedLines();

    // 6. Yeni Blok Oluştur
    if (!isProcessingMatches) {
      spawnNewBlock();
    }
  }

  /// Tüm sıraları kontrol eder ve tamamlananları temizler
  void checkForCompletedLines() {
    List<int> completedLines = []; // Tamamlanan satırların Y indekslerini tut

    // Satırları aşağıdan yukarıya doğru tara (yüksek Y'den düşüğe)
    for (int y = gridHeight - 1; y >= 0; y--) {
      bool lineIsComplete = true;
      // Satırdaki her hücreyi kontrol et
      for (int x = 0; x < gridWidth; x++) {
        if (gridData.getCell(x, y).state != CellState.filled) {
          lineIsComplete = false; // Bir hücre bile boşsa satır tamamlanmamıştır
          break; // Bu satırın kontrolünü bitir
        }
      }

      // Eğer satır tamamsa listeye ekle
      if (lineIsComplete) {
        print("Line complete at y=$y");
        completedLines.add(y);
      }
    }

    // Eğer tamamlanan satır(lar) varsa temizleme ve kaydırma işlemini başlat
    if (completedLines.isNotEmpty) {
      // Skorlama - temizlenen satır sayısına göre puan ekle
      int linesCleared = completedLines.length;
      int pointsEarned = 0;

      switch (linesCleared) {
        case 1:
          pointsEarned = 100; // Tekli
          break;
        case 2:
          pointsEarned = 300; // İkili
          break;
        case 3:
          pointsEarned = 500; // Üçlü
          break;
        case 4:
          pointsEarned = 800; // Dörtlü (Fietris!)
          break;
        default: // 4'ten fazla (mümkünse?)
          pointsEarned = 1000;
      }
      score += pointsEarned; // Skoru güncelle
      updateScoreDisplay(); // Skor göstergesini güncelle
      print(
          "Lines cleared: $linesCleared, Points: +$pointsEarned, Total Score: $score");

      // TODO: Görsel/Ses Efektleri - Satır temizleme efekti ekle

      // Satırları temizle ve üsttekileri kaydır
      clearAndShiftLines(completedLines);
    }
  }

  /// Belirli satırları temizler ve üstündeki tüm satırları aşağı kaydırır
  void clearAndShiftLines(List<int> linesToClear) {
    // Temizlenecek satırları küçükten büyüğe sırala (kaydırmanın doğru çalışması için önemli)
    linesToClear.sort();
    final int numLinesCleared =
        linesToClear.length; // Bu adımda temizlenen satır sayısı

    // Temizlenecek her satır için işlem yap
    for (int clearedY in linesToClear) {
      print("Clearing line y=$clearedY and shifting above rows down.");
      // Bu temizlenen satırın üzerindeki tüm satırları (aşağıdan yukarıya) işle
      for (int y = clearedY; y > 0; y--) {
        // y-1 satırındaki hücreleri y satırına kopyala
        for (int x = 0; x < gridWidth; x++) {
          final cellAbove = gridData.getCell(x, y - 1);
          gridData.setCell(x, y, cellAbove.state, cellAbove.color);
        }
      }

      // En üstteki satırı (y=0) temizle, çünkü artık boş olmalı
      for (int x = 0; x < gridWidth; x++) {
        gridData.setCell(x, 0, CellState.empty, null);
      }
    }

    // Toplam temizlenen satır sayısını güncelle
    linesClearedTotal += numLinesCleared;
    print("Total lines cleared: $linesClearedTotal");

    // Seviye Atlama Kontrolü
    // Gerekli satır sayısına ulaşıldı mı? (Döngü ile birden fazla seviye atlanabilir)
    while (linesClearedTotal >= currentLevel * linesPerLevel) {
      levelUp();
    }

    // Görsel güncelleme otomatik olarak SettledBlocksComponent.render içinde gerçekleşmeli
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (currentState == GameState.gameOver || isProcessingMatches)
      return KeyEventResult.ignored;

    // Oyun bittiyse SADECE yeniden başlatma tuşunu dinle
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR) {
      print("Restart key pressed.");
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
          print("Cannot move left due to collision.");
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
          print("Cannot move right due to collision.");
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
          // b. Otomatik düşme zamanlayıcısını sıfırla (anında çift adım olmasın)
          timeSinceLastFall = 0.0;
          // c. Soft drop için küçük bir skor ekle
          score += 1; // Her başarılı soft drop adımı için 1 puan
          updateScoreDisplay(); // Skor göstergesini güncelle
          print("Soft dropped one step. Score +1: $score");
          return KeyEventResult.handled; // Olay işlendi
        } else {
          // 4. Çarpışma varsa:
          // Hareket ettirme. Normal otomatik düşme mantığı bir sonraki
          // update döngüsünde çarpışmayı algılayıp yerleştirme işlemini tetikleyecek
          print("Soft drop blocked by collision below.");
          return KeyEventResult.handled; // Olay yine de işlendi (tuşa basıldı)
        }
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
    print("--- GAME OVER ---");
    print("Final Score: $score");

    // Düşen bloğu hemen kaldırabilirsin (opsiyonel)
    // if (currentBlock != null) remove(currentBlock!);
    // currentBlock = null;

    // Game Over UI'ını göster
    if (gameOverTextComponent.isMounted) {
      // Component ekli mi kontrol et
      gameOverTextComponent.text = 'GAME OVER\nScore: $score';
    }

    // TODO: Yeniden başlatma butonu/mantığı ekle
  }

  /// Oyunu yeniden başlatır, tüm değişkenleri ve grid'i sıfırlar
  void restartGame() {
    print("Restarting game...");

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

    print("Game Restarted!");
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (currentState != GameState.playing || isProcessingMatches) {
      print("Tap ignored: Game not playing or processing matches.");
      return;
    }

    final Vector2 tapPosition = event.localPosition;
    final gridRect = Rect.fromLTWH(
      gridOrigin.x,
      gridOrigin.y,
      gridWidth * defaultCellSize,
      gridHeight * defaultCellSize,
    );

    if (!gridRect.contains(tapPosition.toOffset())) {
      print("Tap ignored: Outside grid area.");
      return;
    }

    final Vector2 gridCoordsVec = worldToGridCoords(tapPosition);
    final int gridX = gridCoordsVec.x.toInt();
    final int gridY = gridCoordsVec.y.toInt();

    if (!gridData.isWithinBounds(gridX, gridY)) {
      print("Tap ignored: Calculated grid coordinates out of bounds.");
      return;
    }

    final GridCell tappedCell = gridData.getCell(gridX, gridY);
    if (tappedCell.state == CellState.filled && tappedCell.color != null) {
      final Color tappedColor = tappedCell.color!;
      List<Vector2> initialMatches = findMatches(gridX, gridY, tappedColor);

      if (initialMatches.length >= 3) {
        print(
            "Initial match found (${initialMatches.length} blocks). Starting combo processing...");
        isProcessingMatches = true;
        comboMultiplier = 0;
        clearComboDisplay();
        processMatchesAndGravity(initialMatches);
      } else {
        print("Found only ${initialMatches.length} blocks. No combo.");
      }
    } else {
      print(
          "Tap ignored: Cell ($gridX, $gridY) is not filled (state: ${tappedCell.state}).");
    }
  }

  /// Verilen başlangıç noktasından başlayarak, hedef renkle eşleşen ve
  /// birbirine bağlı (4 yönlü) dolu hücrelerin grid koordinatlarını bulur.
  /// BFS algoritmasını kullanır.
  List<Vector2> findMatches(int startX, int startY, Color targetColor) {
    final List<Vector2> matchedCells = []; // Bulunan eşleşen hücreler
    final Queue<Vector2> queue = Queue(); // Ziyaret edilecek hücreler kuyruğu
    final Set<Vector2> visited =
        {}; // Ziyaret edilen veya kuyruğa eklenen hücreler

    // Başlangıç hücresi geçerli mi?
    final startCell = gridData.getCell(startX, startY);
    if (startCell.state != CellState.filled || startCell.color != targetColor) {
      return matchedCells; // Başlangıç hücresi hedefle eşleşmiyorsa boş liste döndür
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
      final List<Vector2> neighborsOffsets = [
        Vector2(0, -1), // Yukarı
        Vector2(0, 1), // Aşağı
        Vector2(-1, 0), // Sol
        Vector2(1, 0), // Sağ
      ];

      for (var offset in neighborsOffsets) {
        final int neighborX = currentX + offset.x.toInt();
        final int neighborY = currentY + offset.y.toInt();
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
    print("Internal Clearing ${matches.length} blocks...");
    for (var matchCoord in matches) {
      final int gridX = matchCoord.x.toInt();
      final int gridY = matchCoord.y.toInt();
      if (gridData.isWithinBounds(gridX, gridY)) {
        gridData.setCell(gridX, gridY, CellState.empty, null);
      }
    }
  }

  // Sadece GridData'ya yerçekimi uygular
  void _applyGravityInternal() {
    print("Internal Applying gravity...");
    for (int x = 0; x < gridWidth; x++) {
      int writeIndex = gridHeight - 1;
      for (int y = gridHeight - 1; y >= 0; y--) {
        final cell = gridData.getCell(x, y);
        if (cell.state == CellState.filled) {
          if (y != writeIndex) {
            gridData.setCell(x, writeIndex, cell.state, cell.color);
            gridData.setCell(x, y, CellState.empty, null);
          }
          writeIndex--;
        }
      }
    }
  }

  /// Tüm grid'i tarar ve 3 veya daha fazla eşleşen blok gruplarını bulur.
  List<Vector2> findNewCombos() {
    print("Checking for new combos...");
    final List<Vector2> allNewMatches = [];
    final Set<Vector2> visitedInCycle = {};

    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final currentVec = Vector2(x.toDouble(), y.toDouble());
        if (!visitedInCycle.contains(currentVec)) {
          final cell = gridData.getCell(x, y);
          if (cell.state == CellState.filled && cell.color != null) {
            List<Vector2> potentialMatch = findMatches(x, y, cell.color!);
            visitedInCycle.addAll(potentialMatch);
            if (potentialMatch.length >= 3) {
              print(
                  "Found combo group of ${potentialMatch.length} at ($x, $y)");
              allNewMatches.addAll(potentialMatch);
            }
          } else {
            visitedInCycle.add(currentVec);
          }
        }
      }
    }
    print(
        "Combo check finished. Found ${allNewMatches.length} blocks in new combos.");
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
    print("Processing Combo x$comboMultiplier");

    int baseScore = calculateMatchScore(matchesToClear.length);
    int currentStepScore = baseScore * comboMultiplier;
    score += currentStepScore;
    updateScoreDisplay();
    print(
        "Scored: base=$baseScore * combo=x$comboMultiplier = $currentStepScore points. Total Score: $score");

    updateComboDisplay();

    _clearMatchesInternal(matchesToClear);
    _applyGravityInternal();

    List<Vector2> nextMatches = findNewCombos();

    if (nextMatches.isNotEmpty) {
      processMatchesAndGravity(nextMatches);
    } else {
      print("Combo chain finished at x$comboMultiplier.");
      isProcessingMatches = false;
      clearComboDisplay();
    }
  }

  /// Verilen seviyeye göre düşme aralığını (saniye) hesaplar.
  double calculateFallIntervalForLevel(int level) {
    // Her seviyede hızı %10 artır (aralığı azalt)
    double interval = 1.0 * pow(0.9, level - 1); // %10 hızlanma (yaklaşık)
    return max(0.08, interval); // Minimum 0.08 saniye aralık (ayarlanabilir)
  }

  /// Seviye atlama işlemlerini yapar
  void levelUp() {
    currentLevel++;
    fallInterval =
        calculateFallIntervalForLevel(currentLevel); // Yeni hızı hesapla
    print(
        "LEVEL UP! Reached Level $currentLevel. Fall interval: $fallInterval");
    updateLevelDisplay(); // Seviye UI'ını güncelle

    // TODO: Seviye atlama ses efekti çal?
    // FlameAudio.play('level_up.wav');
  }

  /// Seviye göstergesini günceller
  void updateLevelDisplay() {
    if (isMounted && children.contains(levelTextComponent)) {
      levelTextComponent.text = 'Level: $currentLevel';
    }
  }

  /// Belirtilen pozisyonda bir temizleme parçacık efekti oluşturur ve döndürür.
  ParticleSystemComponent createClearEffect(
      Vector2 position, Color particleColor) {
    final Random rnd = Random();
    // Rastgele hız ve ömür ile parçacıklar oluştur
    Particle particle = ComputedParticle(
      renderer: (canvas, particle) {
        // Küçülen ve solan bir daire çizelim
        double progress = particle.progress; // 0.0 -> 1.0
        double currentSize = defaultCellSize * 0.3 * (1.0 - progress);
        final paint = Paint()
          ..color = particleColor.withOpacity(1.0 - progress);
        canvas.drawCircle(Offset.zero, currentSize, paint);
      },
    );

    // Parçacık sistemini oluştur
    final particleSystem = ParticleSystemComponent(
      particle: TranslatedParticle(
        offset: position, // Efektin oyun dünyasındaki pozisyonu
        lifespan: 0.6, // Parçacıkların toplam ömrü (saniye)
        child: AcceleratedParticle(
          // Parçacıkların hareketi
          speed: Vector2(rnd.nextDouble() * 100 - 50,
              -rnd.nextDouble() * 150), // Rastgele yukarı ve yanlara hız
          acceleration: Vector2(0, 200), // Yerçekimi benzeri aşağı ivme
          child: particle,
        ),
      ),
      // particleCount: 5, // İsteğe bağlı: Aynı anda kaç parçacık olacağı
    );

    // Efekt bittikten sonra kendini otomatik olarak kaldırmasını sağla
    particleSystem.add(RemoveEffect(delay: 0.6)); // Lifespan ile aynı süre

    return particleSystem;
  }
}
