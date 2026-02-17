import 'package:flutter/material.dart';
import '../../models/graph_node.dart';
import '../../models/graph_link.dart';

class GraphPainter extends CustomPainter {
  final Map<String, GraphNode> nodes;
  final List<GraphLink> links;
  final String? selectedNodeId;
  final Rect? viewport;

  GraphPainter({
    required this.nodes,
    required this.links,
    Listenable? repaintController,
    this.selectedNodeId,
    this.viewport,
  }) : super(repaint: repaintController);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = const Color(0xFF9C27B0)
      ..style = PaintingStyle.fill;

    final selectedNodePaint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.fill;

    final nodeBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw links first
    for (final link in links) {
      final source = nodes[link.sourceId];
      final target = nodes[link.targetId];

      if (source != null && target != null) {
        // Culling for links: if both nodes are outside viewport, skip
        if (viewport != null) {
          if (!viewport!.contains(source.position) &&
              !viewport!.contains(target.position)) {
            continue;
          }
        }
        canvas.drawLine(source.position, target.position, linePaint);
      }
    }

    // Draw nodes
    for (final node in nodes.values) {
      // View Frustum Culling
      if (viewport != null) {
        // Adding radius margin to avoid popping
        if (!viewport!.contains(node.position)) {
          // Check if it's strictly outside (considering radius)
          // Simple AABB check:
          final nodeRect = Rect.fromCircle(
            center: node.position,
            radius: node.radius + 20,
          ); // +20 for label/shadow
          if (!viewport!.overlaps(nodeRect)) {
            continue;
          }
        }
      }

      if (node.id == selectedNodeId) {
        canvas.drawCircle(
          node.position,
          node.radius + 4.0,
          Paint()..color = Colors.yellowAccent.withOpacity(0.3),
        );
        canvas.drawCircle(node.position, node.radius, selectedNodePaint);
      } else {
        canvas.drawCircle(node.position, node.radius, nodePaint);
      }

      canvas.drawCircle(node.position, node.radius, nodeBorderPaint);

      // Use cached TextPainter
      if (node.textPainter != null) {
        node.textPainter!.paint(
          canvas,
          node.position - Offset(node.textPainter!.width / 2, node.radius + 15),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
