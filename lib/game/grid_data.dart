import 'dart:ui';

// Hücre durumu enum'ı
enum CellState {
  empty, // Boş
  filled, // Kalıcı olarak dolu blok
  falling, // Geçici olarak düşen bloğun parçası
}

// Griddeki tek bir hücreyi temsil eden sınıf
class GridCell {
  GridCell({this.state = CellState.empty, this.color});
  CellState state;
  Color? color;
}

// Grid boyutları (sabitler)
const int gridWidth = 10;
const int gridHeight = 20;

// Oyun alanı veri yapısı
class GridData {
  GridData() {
    _grid = List.generate(
      gridWidth,
      (_) => List.generate(
        gridHeight,
        (_) => GridCell(),
      ),
    );
  }
  late List<List<GridCell>> _grid;

  // Sınır kontrolü
  bool isWithinBounds(int x, int y) {
    return x >= 0 && x < gridWidth && y >= 0 && y < gridHeight;
  }

  // Hücreye erişim
  GridCell getCell(int x, int y) {
    if (!isWithinBounds(x, y)) {
      throw RangeError('Grid koordinatları sınır dışında: ($x, $y)');
    }
    return _grid[x][y];
  }

  // Hücre güncelleme
  void setCell(int x, int y, CellState state, Color? color) {
    if (!isWithinBounds(x, y)) return;
    _grid[x][y].state = state;
    _grid[x][y].color = color;
  }

  // Grid'i tamamen temizle (tüm hücreleri boş yap)
  void clearGrid() {
    for (var x = 0; x < gridWidth; x++) {
      for (var y = 0; y < gridHeight; y++) {
        _grid[x][y].state = CellState.empty;
        _grid[x][y].color = null;
      }
    }
  }
}
