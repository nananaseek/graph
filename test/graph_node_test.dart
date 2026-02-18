import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/core/constants.dart';

void main() {
  group('GraphNode Tests', () {
    test('Initial values are correct', () {
      final node = GraphNode(
        id: '1',
        position: const Offset(100, 100),
        label: 'Test Node',
      );

      expect(node.id, '1');
      expect(node.position, const Offset(100, 100));
      expect(node.label, 'Test Node');
      expect(node.mass, 1.0);
      expect(node.radius, 18.0);
      expect(node.velocity, Offset.zero);
    });

    test('updateSize scales mass and radius correctly based on degree', () {
      final node = GraphNode(id: '1', position: Offset.zero, label: 'Test');

      // Base values
      const baseRadius = 18.0;
      const baseMass = 1.0;

      // Test with 0 connections
      node.updateSize(0);
      expect(node.radius, baseRadius);
      expect(node.mass, baseMass);

      // Test with 1 connection
      node.updateSize(1);
      expect(node.radius, baseRadius + 1.1);
      expect(node.mass, baseMass + AppConstants.connectionMassModifier);

      // Test with 10 connections
      node.updateSize(10);
      expect(node.radius, baseRadius + (10 * 1.1));
      expect(node.mass, baseMass + (10 * AppConstants.connectionMassModifier));
    });

    test('TextPainter updates when mass changes', () {
      final node = GraphNode(id: '1', position: Offset.zero, label: 'Test');

      final initialPainter = node.textPainter;

      // Update with same degree (0) - logic says it checks if mass != _lastMass
      // Initial mass is 1.0 (degree 0).
      // updateSize(0) sets mass to 1.0. So no change.
      node.updateSize(0);
      expect(node.textPainter, initialPainter);

      // Update with higher degree -> mass changes -> painter should recreate
      node.updateSize(5);
      expect(node.textPainter, isNot(initialPainter));

      // Check font size indirectly if possible, or just correctness of updates
      // We can't easily check internal TextSpan style without accessing the painter's text property casted.
      final textSpan = node.textPainter!.text as TextSpan;
      final style = textSpan.style!;

      // Expected font size: 11 + (mass * 1.5)
      // Mass for degree 5 = 1.0 + (5 * 0.2) = 2.0 (assuming constant is 0.2, need to check)
      // Let's rely on the formula in code: 11 + (mass * 1.5)

      final expectedFontSize = 11 + (node.mass * 1.5);
      expect(style.fontSize, expectedFontSize);
    });
  });
}
