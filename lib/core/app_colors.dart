import 'package:flutter/material.dart';

class AppColors {
  /// Palette for different generations (depths) in the graph.
  /// 0 = Root node, 1 = 1st level children, etc.
  /// It cycles through 7 colors.
  static const List<Color> generationColors = [
    Color(0xFF80CDE3), // 1-ше покоління (Корінь - Базовий)
    Color(0xFF808DE3), // 2-ге покоління
    Color(0xFFC080E3), // 3-тє покоління
    Color(0xFFE380A8), // 4-те покоління
    Color(0xFFE3A880), // 5-те покоління
    Color(0xFFCBE380), // 6-те покоління
    Color(0xFF80E3A2), // 7-ме покоління
  ];

  /// Returns the color appropriate for the given depth, cycling if needed.
  static Color getGenerationColor(int depth) {
    if (depth < 0) return generationColors[0];
    return generationColors[depth % generationColors.length];
  }
}
