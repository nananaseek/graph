import 'package:flutter/material.dart';
import '../../models/graph_node.dart';
import '../../models/graph_link.dart';
import '../painters/graph_painter.dart';

class GraphRenderer extends StatelessWidget {
  final Map<String, GraphNode> nodes;
  final List<GraphLink> links;
  final ValueNotifier<int> tickNotifier;
  final String? selectedNodeId;
  final Rect? viewport;

  const GraphRenderer({
    super.key,
    required this.nodes,
    required this.links,
    required this.tickNotifier,
    this.selectedNodeId,
    this.viewport,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GraphPainter(
          nodes: nodes,
          links: links,
          repaintController: tickNotifier,
          selectedNodeId: selectedNodeId,
          viewport: viewport,
        ),
      ),
    );
  }
}
