import 'package:flutter/material.dart';
import '../core/constants.dart';

class GraphNode {
  String id;
  Offset position;
  Offset velocity;
  String label;

  /// Display name for side panel
  String name;

  /// Generated money value
  double generatedMoney;

  /// Number of connections
  int connectionCount;

  /// IDs of attached nodes
  List<String> attachedNodeIds;

  /// Parent node ID (null = master / root node)
  String? parentId;

  /// Children (slave) node IDs
  List<String> childrenIds;

  /// Whether this is a master (root-level) node
  bool get isMaster => parentId == null;

  double mass;
  double radius;

  double appearanceScale;

  TextPainter? textPainter;
  double _lastMass = -1;

  GraphNode({
    required this.id,
    required this.position,
    required this.label,
    this.name = '',
    this.velocity = Offset.zero,
    this.mass = 1.0,
    this.radius = 18.0,
    this.appearanceScale = 0.0,
    this.generatedMoney = 0.0,
    this.connectionCount = 0,
    this.parentId,
    List<String>? attachedNodeIds,
    List<String>? childrenIds,
  }) : attachedNodeIds = attachedNodeIds ?? [],
       childrenIds = childrenIds ?? [] {
    if (name.isEmpty) name = label;
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
    connectionCount = degree;

    if (mass != _lastMass) {
      _lastMass = mass;
      _updateTextPainter();
    }
  }
}
