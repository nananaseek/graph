import 'package:flutter/material.dart';
import '../core/constants.dart';

class GraphNode {
  String id;
  Offset position;
  Offset velocity;
  String label;

  double mass;
  double radius;

  /// Visual-only scale factor for appearance animation (0.0 = invisible, 1.0 = full size).
  /// Does not affect physics — only rendering.
  double appearanceScale;

  TextPainter? textPainter;
  double _lastMass = -1;

  GraphNode({
    required this.id,
    required this.position,
    required this.label,
    this.velocity = Offset.zero,
    this.mass = 1.0,
    this.radius = 18.0,
    this.appearanceScale = 0.0,
  }) {
    _lastMass = mass;
    _updateTextPainter();
  }

  void _updateTextPainter() {
    textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11 + (mass * 1.5),
          fontWeight: FontWeight.w500,
          shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
  }

  void updateSize(int degree) {
    const baseRadius = 18.0;
    const baseMass = 1.0;

    radius = baseRadius + (degree * 1.1);
    mass = baseMass + (degree * AppConstants.connectionMassModifier);

    // Only rebuild TextPainter if mass changed (affects fontSize)
    if (mass != _lastMass) {
      _lastMass = mass;
      _updateTextPainter();
    }
  }
}
