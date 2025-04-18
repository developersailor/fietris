import 'dart:ui';
import 'package:fietris/game/grid_background.dart';
import 'package:fietris/game/grid_config.dart';
import 'package:fietris/game/grid_data.dart';
import 'package:fietris/game/blocks/block.dart';
import 'package:fietris/game/blocks/block_type.dart';
import 'package:fietris/game/components/touch_controls.dart';
import 'package:fietris/game/components/settled_blocks_component.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart'; // KeyboardEvents için
import 'package:flame/components.dart'
    hide Block; // TextComponent için, Block hariç
import 'package:flame/text.dart'; // TextPaint için
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter/services.dart'; // LogicalKeyboardKey için
import 'package:flutter/widgets.dart'; // KeyEventResult için
import 'package:flutter/material.dart' show Colors, TextStyle, Shadow, Offset;

// Oyun durumları
enum GameState { playing, gameOver }

class FietrisGame extends FlameGame with KeyboardEvents, TapCallbacks {
  late GridData gridData;
  Block? currentBlock; // Şu an düşmekte olan blok
  Vector2 gridOrigin = Vector2(50, 50); // GridBackground ile aynı pozisyon
  late SettledBlocksComponent
      settledBlocksComponent; // Yerleşen blokları gösterecek component

  int score = 0; // Oyuncu skoru
  late TextComponent scoreTextComponent;
  late final TextPaint scoreTextPaint;

  // Game Over UI için
  late TextComponent gameOverTextComponent;

  // Oyun durumu
  GameState currentState = GameState.playing; // Başlangıç durumu

  double fallInterval = 1.0; // Her bir adım için saniye cinsinden süre
  double timeSinceLastFall = 0.0; // Son düşme adımından beri geçen süre

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

    final randomType = BlockType.getRandom();
    int startX = gridWidth ~/ 2;
    int startY = 0;

    // === DÜZELTME: Spawn Alanı Kontrolü ===
    // Blok oluşturmadan önce, yerleşeceği grid hücreleri dolu mu diye bak
    for (var pieceOffset in randomType.shape) {
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
      blockType: randomType,
      cellSize: defaultCellSize,
      initialPosition: spawnPosition,
    );
    add(currentBlock!);
    print("Spawned new block: $randomType at $spawnPosition");
  }

  @override
  void update(double dt) {
    if (currentState == GameState.gameOver)
      return; // Oyun bittiyse güncelleme yapma

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

  /// Düşen bloğu grid'e yerleştirir ve yeni bir blok oluşturur
  void settleBlock() {
    if (currentBlock == null) return;

    print("Settling block: ${currentBlock!.blockType}");

    final shape = currentBlock!.blockType.shape;
    final blockColor = currentBlock!.color;
    final blockWorldPos = currentBlock!.position;
    final cellSz = currentBlock!.cellSize;

    // 1. Grid Verisini Güncelle
    for (var pieceOffset in shape) {
      // Parçanın mutlak dünya pozisyonu
      final pieceWorldPos = Vector2(
        blockWorldPos.x + pieceOffset.x * cellSz,
        blockWorldPos.y + pieceOffset.y * cellSz,
      );
      // Dünya pozisyonunu grid koordinatlarına çevir
      final gridCoords = worldToGridCoords(pieceWorldPos);
      final gridX = gridCoords.x.toInt();
      final gridY = gridCoords.y.toInt();

      // === YENİ: Tavan Kontrolü ===
      if (gridY < 0) {
        print("GAME OVER: Block settled partially above ceiling at y=$gridY.");
        gameOver();
        // return; // gameOver zaten durumu değiştirip update'i durduracak
      }
      // =========================

      // GridData'daki ilgili hücreyi güncelle
      if (gridData.isWithinBounds(gridX, gridY)) {
        gridData.setCell(gridX, gridY, CellState.filled, blockColor);
        print(
            "Updated gridData at ($gridX, $gridY) to filled with $blockColor");
      } else {
        print(
            "Warning: Attempted to settle block piece outside bounds at ($gridX, $gridY)");
      }
    }

    // 2. Düşen Blok Component'ini Kaldır
    remove(currentBlock!);

    // 3. Mevcut Blok Referansını Temizle
    currentBlock = null;

    // 4. Görsel Güncelleme (artık SettledBlocksComponent tarafından otomatik yapılıyor)

    // 5. Tamamlanan Sıraları Kontrol Et ve Temizle
    checkForCompletedLines();

    // 6. Yeni Blok Oluştur
    spawnNewBlock();
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
    // Görsel güncelleme otomatik olarak SettledBlocksComponent.render içinde gerçekleşmeli
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Oyun bittiyse SADECE yeniden başlatma tuşunu dinle
    if (currentState == GameState.gameOver) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyR) {
        print("Restart key pressed.");
        restartGame(); // Yeniden başlatma metodunu çağır
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // Oyun bittiyse diğer tuşları yoksay
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
    // Gerekirse seviye veya düşme hızı gibi diğer değişkenleri de sıfırla
    // level = 1; fallInterval = 1.0;

    // 2. Grid Verisini Temizle
    gridData.clearGrid(); // GridData'daki tüm hücreleri 'empty' yap

    // 3. Görselleri Temizle/Sıfırla
    //    a. Mevcut düşen bloğu kaldır (varsa)
    if (currentBlock != null) {
      remove(currentBlock!);
      currentBlock = null;
    }

    //    b. Game Over mesajını temizle
    if (gameOverTextComponent.isMounted) {
      gameOverTextComponent.text = '';
    }

    // 4. Skor Göstergesini Güncelle
    updateScoreDisplay(); // Skoru 0 olarak göster

    // 5. İlk Bloğu Oluştur
    spawnNewBlock();

    print("Game Restarted!");
  }
}
