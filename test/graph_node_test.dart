import 'dart:math';
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

    test(
      'updateSize scales mass and radius correctly based on descendant money',
      () {
        final node = GraphNode(id: '1', position: Offset.zero, label: 'Test');

        const baseRadius = 18.0;
        const baseMass = 1.0;

        // Test with 0 money
        node.updateSize(0.0);
        expect(node.radius, baseRadius);
        expect(node.mass, baseMass);

        // Test with some money (e.g. 100)
        node.updateSize(100.0);
        final factor100 = log(101) / log(10);
        expect(node.radius, closeTo(baseRadius + (factor100 * 3.0), 0.01));
        expect(
          node.mass,
          closeTo(
            baseMass + (factor100 * AppConstants.connectionMassModifier),
            0.01,
          ),
        );

        // Test with large money (e.g. 10000)
        node.updateSize(10000.0);
        final factor10k = log(10001) / log(10);
        expect(node.radius, closeTo(baseRadius + (factor10k * 3.0), 0.01));
        expect(
          node.mass,
          closeTo(
            baseMass + (factor10k * AppConstants.connectionMassModifier),
            0.01,
          ),
        );
      },
    );

    test('TextPainter updates when mass changes', () {
      final node = GraphNode(id: '1', position: Offset.zero, label: 'Test');

      final initialPainter = node.textPainter;

      // Update with 0 money - mass stays 1.0, same as initial
      node.updateSize(0.0);
      expect(node.textPainter, initialPainter);

      // Update with money -> mass changes -> painter should recreate
      node.updateSize(1000.0);
      expect(node.textPainter, isNot(initialPainter));

      final textSpan = node.textPainter!.text as TextSpan;
      final style = textSpan.style!;

      final expectedFontSize = 11 + (node.mass * 1.5);
      expect(style.fontSize, expectedFontSize);
    });
  });
}
