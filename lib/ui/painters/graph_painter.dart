import 'package:flutter/material.dart';
import '../../models/graph_node.dart';
import '../../models/graph_link.dart';

class GraphPainter extends CustomPainter {
  final Map<String, GraphNode> nodes;
  final List<GraphLink> links;
  final String? selectedNodeId;
  final Rect? viewport;

  final Paint _linePaint = Paint()
    ..color = const Color.fromRGBO(128, 205, 227, 0.35)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  final Paint _nodePaint = Paint()
    ..color = const Color(0xFF80cde3)
    ..style = PaintingStyle.fill;

  final Paint _selectedNodePaint = Paint()
    ..color = const Color(0xFFFFB347)
    ..style = PaintingStyle.fill;

  final Paint _glowOuter = Paint()
    ..color = const Color.fromRGBO(255, 179, 71, 0.15)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

  final Paint _glowMid = Paint()
    ..color = const Color.fromRGBO(255, 179, 71, 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  final Paint _glowInner = Paint()
    ..color = const Color.fromRGBO(255, 220, 140, 0.65)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  final Paint _selectedBorderPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  final Paint _nodeGlowPaint = Paint()
    ..color = const Color.fromRGBO(128, 205, 227, 0.25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  GraphPainter({
    required this.nodes,
    required this.links,
    Listenable? repaintController,
    this.selectedNodeId,
    this.viewport,
  }) : super(repaint: repaintController);

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport != null) {
      canvas.save();
      canvas.clipRect(viewport!);
    }

    // Draw links — hide if either node hasn't appeared enough
    for (final link in links) {
      final source = nodes[link.sourceId];
      final target = nodes[link.targetId];

      if (source != null && target != null) {
        // Skip links where either node is still too small
        if (source.appearanceScale < 0.5 || target.appearanceScale < 0.5) {
          continue;
        }

        // Culling for links: if both nodes are outside viewport, skip
        if (viewport != null) {
          if (!viewport!.contains(source.position) &&
              !viewport!.contains(target.position)) {
            continue;
          }
        }
        canvas.drawLine(source.position, target.position, _linePaint);
      }
    }

    // Draw nodes
    for (final node in nodes.values) {
      // Skip fully invisible nodes
      if (node.appearanceScale <= 0.0) continue;

      // View Frustum Culling
      if (viewport != null) {
        // Adding radius margin to avoid popping
        if (!viewport!.contains(node.position)) {
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

      // Use pre-clamped scale from node (already 0..1)
      final scaledRadius = node.radius * node.appearanceScale;

      if (node.id == selectedNodeId) {
        canvas.drawCircle(node.position, scaledRadius + 18, _glowOuter);
        canvas.drawCircle(node.position, scaledRadius + 9, _glowMid);
        canvas.drawCircle(node.position, scaledRadius + 3, _glowInner);

        canvas.drawCircle(node.position, scaledRadius, _selectedNodePaint);
        canvas.drawCircle(node.position, scaledRadius, _selectedBorderPaint);
      } else {
        canvas.drawCircle(node.position, scaledRadius + 5, _nodeGlowPaint);
        canvas.drawCircle(node.position, scaledRadius, _nodePaint);
      }

      // Text: show only when fully appeared — no canvas.save/scale/restore overhead
      if (node.textPainter != null && node.appearanceScale >= 1.0) {
        node.textPainter!.paint(
          canvas,
          node.position - Offset(node.textPainter!.width / 2, node.radius + 15),
        );
      }
    }

    if (viewport != null) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return selectedNodeId != oldDelegate.selectedNodeId ||
        viewport != oldDelegate.viewport;
  }
}
