import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/graph_node.dart';
import '../models/graph_link.dart';

/// Service managing the full node graph, hierarchy, and visible subset.
///
/// Only master nodes are visible on start. Expanding a node via long-press
/// reveals its slave children on the canvas.
class GraphDataService {
  static const _uuid = Uuid();

  /// Complete graph of ALL nodes (visible + hidden).
  final Map<String, GraphNode> allNodes = {};

  /// Links between ALL nodes.
  final List<GraphLink> allLinks = [];

  /// Currently visible nodes on the canvas.
  final ValueNotifier<int> visibleTickNotifier = ValueNotifier(0);
  final Map<String, GraphNode> visibleNodes = {};

  /// Currently visible links (only between visible nodes).
  final List<GraphLink> visibleLinks = [];

  /// Set of expanded node IDs (whose children are visible).
  final Set<String> _expandedNodeIds = {};

  /// Cache: nodeId → pre-calculated positions for slave nodes.
  final Map<String, List<Offset>> _childPositionCache = {};

  /// Returns only root-level master nodes.
  List<GraphNode> get masterNodes =>
      allNodes.values.where((n) => n.isMaster).toList();

  /// Returns children of a given node.
  List<GraphNode> getChildren(String nodeId) {
    final node = allNodes[nodeId];
    if (node == null) return [];
    return node.childrenIds
        .map((id) => allNodes[id])
        .whereType<GraphNode>()
        .toList();
  }

  /// Returns the node by ID.
  GraphNode? getNode(String id) => allNodes[id];

  /// Expands slave nodes of [nodeId] onto the canvas.
  void expandChildren(String nodeId) {
    final node = allNodes[nodeId];
    if (node == null || node.childrenIds.isEmpty) return;
    if (_expandedNodeIds.contains(nodeId)) return;

    _expandedNodeIds.add(nodeId);

    // Calculate child positions in a circle around the parent
    final children = getChildren(nodeId);
    final positions = _getChildPositions(node, children.length);

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      child.position = positions[i];
      child.appearanceScale = 0.0; // Will animate in
      visibleNodes[child.id] = child;
    }

    // Add links from parent to children
    for (final child in children) {
      final link = allLinks.firstWhere(
        (l) =>
            (l.sourceId == nodeId && l.targetId == child.id) ||
            (l.sourceId == child.id && l.targetId == nodeId),
        orElse: () {
          final newLink = GraphLink(nodeId, child.id);
          allLinks.add(newLink);
          return newLink;
        },
      );
      if (!visibleLinks.contains(link)) {
        visibleLinks.add(link);
      }
    }

    _rebuildVisibleLinks();
    visibleTickNotifier.value++;
  }

  /// Collapses slave nodes of [nodeId], removing them from the canvas.
  void collapseChildren(String nodeId) {
    if (!_expandedNodeIds.contains(nodeId)) return;
    _expandedNodeIds.remove(nodeId);

    final node = allNodes[nodeId];
    if (node == null) return;

    // Recursively collapse grandchildren first
    for (final childId in node.childrenIds) {
      collapseChildren(childId);
      visibleNodes.remove(childId);
    }

    _rebuildVisibleLinks();
    visibleTickNotifier.value++;
  }

  /// Whether children of [nodeId] are currently expanded on canvas.
  bool isExpanded(String nodeId) => _expandedNodeIds.contains(nodeId);

  /// Pre-calculate positions for N children around a parent node.
  List<Offset> _getChildPositions(GraphNode parent, int count) {
    final cacheKey = '${parent.id}_$count';
    if (_childPositionCache.containsKey(cacheKey)) {
      // Re-center cache around current parent position
      final cached = _childPositionCache[cacheKey]!;
      final deltaX = parent.position.dx;
      final deltaY = parent.position.dy;
      return cached.map((p) => Offset(p.dx + deltaX, p.dy + deltaY)).toList();
    }

    final positions = <Offset>[];
    const baseDistance = 120.0;
    final angleStep = (2 * pi) / count;

    for (int i = 0; i < count; i++) {
      final angle = angleStep * i - pi / 2;
      positions.add(
        Offset(cos(angle) * baseDistance, sin(angle) * baseDistance),
      );
    }

    // Cache relative positions (zero-centered)
    _childPositionCache[cacheKey] = positions;

    // Return absolute positions
    return positions
        .map(
          (p) => Offset(p.dx + parent.position.dx, p.dy + parent.position.dy),
        )
        .toList();
  }

  /// Rebuild visible links — only links where both endpoints are visible.
  void _rebuildVisibleLinks() {
    visibleLinks.clear();
    for (final link in allLinks) {
      if (visibleNodes.containsKey(link.sourceId) &&
          visibleNodes.containsKey(link.targetId)) {
        visibleLinks.add(link);
      }
    }
  }

  /// Initialize with mock hierarchical data.
  void initMockData() {
    allNodes.clear();
    allLinks.clear();
    visibleNodes.clear();
    visibleLinks.clear();
    _expandedNodeIds.clear();
    _childPositionCache.clear();

    final rng = Random(42);

    // --- Master nodes ---
    final masterData = [
      ('Alpha Network', 15200.0),
      ('Beta Hub', 8730.0),
      ('Gamma Core', 22100.0),
      ('Delta Node', 5400.0),
      ('Epsilon Cluster', 31050.0),
    ];

    final masterIds = <String>[];

    for (int i = 0; i < masterData.length; i++) {
      final id = _uuid.v4();
      final angle = (2 * pi / masterData.length) * i - pi / 2;
      final dist = 180.0 + rng.nextDouble() * 60;

      final node = GraphNode(
        id: id,
        position: Offset(cos(angle) * dist, sin(angle) * dist),
        label: masterData[i].$1,
        name: masterData[i].$1,
        generatedMoney: masterData[i].$2,
      );

      allNodes[id] = node;
      masterIds.add(id);
    }

    // Links between some master nodes
    allLinks.add(GraphLink(masterIds[0], masterIds[1]));
    allLinks.add(GraphLink(masterIds[0], masterIds[2]));
    allLinks.add(GraphLink(masterIds[1], masterIds[3]));
    allLinks.add(GraphLink(masterIds[2], masterIds[4]));
    allLinks.add(GraphLink(masterIds[3], masterIds[4]));

    // --- Slave nodes (level 2) ---
    for (final masterId in masterIds) {
      final childCount = 2 + rng.nextInt(4); // 2..5 children
      for (int j = 0; j < childCount; j++) {
        final childId = _uuid.v4();
        final childNode = GraphNode(
          id: childId,
          position: Offset.zero, // Will be positioned on expand
          label: '${allNodes[masterId]!.label} L$j',
          name: '${allNodes[masterId]!.name} — Slave $j',
          generatedMoney: (rng.nextDouble() * 5000).roundToDouble(),
          parentId: masterId,
        );
        allNodes[childId] = childNode;
        allNodes[masterId]!.childrenIds.add(childId);
        allLinks.add(GraphLink(masterId, childId));

        // --- Level 3 slaves (some children have sub-children) ---
        if (rng.nextBool()) {
          final subCount = 1 + rng.nextInt(3);
          for (int k = 0; k < subCount; k++) {
            final subId = _uuid.v4();
            final subNode = GraphNode(
              id: subId,
              position: Offset.zero,
              label: '${childNode.label}.$k',
              name: '${childNode.name} — Sub $k',
              generatedMoney: (rng.nextDouble() * 1000).roundToDouble(),
              parentId: childId,
            );
            allNodes[subId] = subNode;
            childNode.childrenIds.add(subId);
            allLinks.add(GraphLink(childId, subId));
          }
        }
      }
    }

    // Update connection counts
    for (final node in allNodes.values) {
      node.connectionCount = allLinks
          .where((l) => l.sourceId == node.id || l.targetId == node.id)
          .length;
      node.attachedNodeIds = allLinks
          .where((l) => l.sourceId == node.id || l.targetId == node.id)
          .map((l) => l.sourceId == node.id ? l.targetId : l.sourceId)
          .toList();
    }

    // Only master nodes visible on start
    for (final id in masterIds) {
      visibleNodes[id] = allNodes[id]!;
    }
    _rebuildVisibleLinks();

    visibleTickNotifier.value++;
  }
}
