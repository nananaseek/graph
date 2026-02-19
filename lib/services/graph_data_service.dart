import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/graph_node.dart';
import '../models/graph_link.dart';
import '../core/service_locator.dart';
import 'debug_service.dart';

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

  /// Currently focused node ID.
  final ValueNotifier<String?> focusedNodeId = ValueNotifier(null);

  /// Helper to get the parent of a node.
  GraphNode? getParent(String nodeId) {
    final node = allNodes[nodeId];
    if (node == null || node.parentId == null) return null;
    return allNodes[node.parentId];
  }

  /// Sets the currently focused node and updates visibility.
  void setFocus(String? nodeId) {
    if (focusedNodeId.value == nodeId) return;
    focusedNodeId.value = nodeId;
    updateVisibility();
  }

  /// Updates the set of visible nodes based on focus rules.
  /// 1. Roots are always visible.
  /// 2. Active Path (ancestors of focused) are visible.
  /// 3. Children of focused node are visible.
  void updateVisibility() {
    final newVisibleNodes = <String, GraphNode>{};

    // Check debug mode first
    // We access it via getIt to avoid circular dependency in constructor if any
    if (getIt.isRegistered<DebugService>()) {
      final debugService = getIt<DebugService>();
      if (debugService.showAllNodes.value) {
        newVisibleNodes.addAll(allNodes);
        visibleNodes.clear();
        visibleNodes.addAll(newVisibleNodes);
        _rebuildVisibleLinks();
        visibleTickNotifier.value++;
        return;
      }
    }

    // 1. Root nodes always visible
    for (final node in allNodes.values) {
      if (node.isMaster) {
        newVisibleNodes[node.id] = node;
      }
    }

    final focusId = focusedNodeId.value;
    if (focusId != null && allNodes.containsKey(focusId)) {
      var currentId = focusId;

      // 2. Active Path (Ancestors)
      // Traverse up from focused node to root, ensuring all are visible
      while (true) {
        final node = allNodes[currentId];
        if (node == null) break;

        newVisibleNodes[node.id] = node;

        if (node.parentId == null) break;
        currentId = node.parentId!;
      }

      // 3. Children of focused node
      final focusedNode = allNodes[focusId];
      if (focusedNode != null && focusedNode.childrenIds.isNotEmpty) {
        final children = getChildren(focusId);
        // Calculate positions if needed (using existing logic)
        final positions = _getChildPositions(focusedNode, children.length);

        for (int i = 0; i < children.length; i++) {
          final child = children[i];
          // If child was not already visible, set its position and animate
          if (!visibleNodes.containsKey(child.id)) {
            child.position = positions[i];
            child.appearanceScale = 0.0;
          }
          newVisibleNodes[child.id] = child;
        }
      }
    }

    // Update visibleNodes map
    visibleNodes.clear();
    visibleNodes.addAll(newVisibleNodes);

    // Rebuild links
    _rebuildVisibleLinks();
    visibleTickNotifier.value++;
  }

  /// Helper to get cached or calculated positions for children.
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

  // --- CRUD Operations ---

  /// Creates a new Root Node.
  void createRootNode() {
    final id = _uuid.v4();
    // Position randomly near center or offset
    final node = GraphNode(
      id: id,
      position: const Offset(
        100,
        100,
      ), // Default position, forces user to drag?
      label: 'New Root',
      name: 'New Root',
      selfGeneratedMoney: 0,
    );
    allNodes[id] = node;

    // Automatically focus on it? Or just show it.
    // Roots are always visible.
    updateVisibility();
  }

  /// Creates a new Slave Node attached to [parentId].
  void createSlaveNode(String parentId) {
    final parent = allNodes[parentId];
    if (parent == null) return;

    final id = _uuid.v4();
    final node = GraphNode(
      id: id,
      position: parent.position, // Start at parent position (will expand out)
      label: 'New Slave',
      name: 'New Slave',
      selfGeneratedMoney: 0,
      parentId: parentId,
    );

    allNodes[id] = node;
    parent.childrenIds.add(id);
    allLinks.add(GraphLink(parentId, id));

    // Update connection count for parent (basic increment)
    parent.connectionCount++;
    parent.attachedNodeIds.add(id);

    node.connectionCount = 1;
    node.attachedNodeIds.add(parentId);

    // If we create a slave, we probably want to see it.
    // Ensure parent is focused or visible.
    updateVisibility();
  }

  /// Deletes a node and all its descendants.
  void deleteNode(String nodeId) {
    // 1. Collect all descendants (recursive) to delete
    final nodesToDelete = <String>{nodeId};
    _collectDescendants(nodeId, nodesToDelete);

    // 2. Remove from data structures
    for (final id in nodesToDelete) {
      allNodes.remove(id);
      visibleNodes.remove(id);

      // Remove links connected to this node
      allLinks.removeWhere((l) => l.sourceId == id || l.targetId == id);
    }

    // 3. Cleanup references in parents/neighbors
    for (final node in allNodes.values) {
      node.childrenIds.removeWhere(
        (childId) => nodesToDelete.contains(childId),
      );
      node.attachedNodeIds.removeWhere(
        (attId) => nodesToDelete.contains(attId),
      );
      // Re-caclulate connection count?
      node.connectionCount = allLinks
          .where((l) => l.sourceId == node.id || l.targetId == node.id)
          .length;
    }

    // 4. Update focus if focused node was deleted
    if (focusedNodeId.value != null &&
        nodesToDelete.contains(focusedNodeId.value)) {
      focusedNodeId.value = null;
    }

    updateVisibility();
  }

  void _collectDescendants(String nodeId, Set<String> result) {
    final children = getChildren(nodeId);
    for (final child in children) {
      result.add(child.id);
      _collectDescendants(child.id, result);
    }
  }

  /// Updates the money of a node (and potentially triggers UI update).
  void updateNode(String nodeId, {String? name, double? money}) {
    final node = allNodes[nodeId];
    if (node == null) return;

    if (name != null) node.name = name;
    if (money != null) node.selfGeneratedMoney = money;

    // Trigger update? Notifiers?
    // SidePanel might need to know if it's showing this node.
    // For now, SidePanel rebuilds when selection changes, but not when data changes?
    // We might need a "nodeUpdated" notifier or similar if we want instant UI feedback while editing?
    // Or just call updateVisibility (which triggers visibleTick)?
    visibleTickNotifier.value++;
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
        selfGeneratedMoney: masterData[i].$2,
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
          selfGeneratedMoney: (rng.nextDouble() * 5000).roundToDouble(),
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
              selfGeneratedMoney: (rng.nextDouble() * 1000).roundToDouble(),
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

    // Initial visibility update (roots only)
    updateVisibility();
  }
}
