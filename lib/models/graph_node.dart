import 'package:flutter/material.dart';
import '../core/constants.dart';

class GraphNode {
  String id;
  Offset position;
  Offset velocity;
  String label;

  double mass;
  double radius;

  TextPainter? textPainter;
  double _lastMass = -1;

  GraphNode({
    required this.id,
    required this.position,
    required this.label,
    this.velocity = Offset.zero,
    this.mass = 1.0,
    this.radius = 18.0,
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
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
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
