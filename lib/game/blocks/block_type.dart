import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

// Define shapes as const lists of coordinate pairs using records
const List<({double x, double y})> _iShapeCoords = [
  (x: 0, y: 0),
  (x: -1, y: 0),
  (x: 1, y: 0),
  (x: 2, y: 0),
];
const List<({double x, double y})> _oShapeCoords = [
  (x: 0, y: 0),
  (x: 1, y: 0),
  (x: 0, y: 1),
  (x: 1, y: 1),
];
const List<({double x, double y})> _tShapeCoords = [
  (x: 0, y: 0),
  (x: -1, y: 0),
  (x: 1, y: 0),
  (x: 0, y: -1),
];
const List<({double x, double y})> _sShapeCoords = [
  (x: 0, y: 0),
  (x: 1, y: 0),
  (x: 0, y: -1),
  (x: -1, y: -1),
];
const List<({double x, double y})> _zShapeCoords = [
  (x: 0, y: 0),
  (x: -1, y: 0),
  (x: 0, y: -1),
  (x: 1, y: -1),
];
const List<({double x, double y})> _jShapeCoords = [
  (x: 0, y: 0),
  (x: -1, y: 0),
  (x: 1, y: 0),
  (x: 1, y: -1),
];
const List<({double x, double y})> _lShapeCoords = [
  (x: 0, y: 0),
  (x: -1, y: 0),
  (x: 1, y: 0),
  (x: -1, y: -1),
];

// Helper function to convert coordinate lists to Vector2 lists
List<Vector2> _coordsToVectors(List<({double x, double y})> coords) {
  return coords.map((c) => Vector2(c.x, c.y)).toList();
}

enum BlockType {
  I(shapeCoords: _iShapeCoords, color: Colors.cyan),
  O(shapeCoords: _oShapeCoords, color: Colors.yellow),
  T(shapeCoords: _tShapeCoords, color: Colors.purple),
  S(shapeCoords: _sShapeCoords, color: Colors.green),
  Z(shapeCoords: _zShapeCoords, color: Colors.red),
  J(shapeCoords: _jShapeCoords, color: Colors.blue),
  L(shapeCoords: _lShapeCoords, color: Colors.orange);

  const BlockType({
    required List<({double x, double y})> shapeCoords,
    required this.color,
  }) : _shapeCoords = shapeCoords;

  // Store the const coordinate data
  final List<({double x, double y})> _shapeCoords;
  final Color color;

  // Const constructor using the coordinate data

  // Public getter to provide the List<Vector2> shape on demand
  List<Vector2> get shape => _coordsToVectors(_shapeCoords);

  static BlockType getRandom() {
    final random = Random();
    return BlockType.values[random.nextInt(BlockType.values.length)];
  }
}
