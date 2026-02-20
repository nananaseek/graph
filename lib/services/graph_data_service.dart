import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/graph_node.dart';
import '../models/graph_link.dart';
import '../core/service_locator.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
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
      position: const Offset(100, 100),
      label: 'New Root',
      name: 'New Root',
      selfGeneratedMoney: 0,
    );
    allNodes[id] = node;

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

    visibleTickNotifier.value++;
  }

  /// Loads demo data from assets.
  Future<void> loadDemoData() async {
    try {
      isLoading.value = true;

      // Artificial delay to show loading state (optional, but good for UX feel)
      await Future.delayed(const Duration(milliseconds: 500));

      final jsonString = await rootBundle.loadString('assets/demo_graph.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      _parseAndLoadGraph(jsonList);
    } catch (e) {
      debugPrint('Error loading demo data: $e');
      // Fallback or error handling?
    } finally {
      isLoading.value = false;
    }
  }

  /// Exports the current graph to a JSON file.
  Future<void> exportGraph() async {
    try {
      isLoading.value = true;

      final jsonList = masterNodes
          .map((node) => node.toJson(allNodes: allNodes))
          .toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final fileName =
          'graph_export_${DateTime.now().millisecondsSinceEpoch}.json';

      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Graph',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

    } catch (e) {
      debugPrint('Error exporting graph: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Imports a graph from a JSON file.
  Future<void> importGraph() async {
    try {
        Directory? initialDirectory = await getDownloadsDirectory();

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        initialDirectory: initialDirectory.toString(),
        withData: true, // Important for Web/WASM
      );

      if (result == null || result.files.isEmpty) return;

      isLoading.value = true;

      final file = result.files.first;

      String jsonString;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('File bytes are null');
        jsonString = utf8.decode(bytes);
      } else {
        if (file.bytes != null) {
          jsonString = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          jsonString = await File(file.path!).readAsString();
        } else {
          throw Exception('Unable to read file content');
        }
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);

      _parseAndLoadGraph(jsonList);
    } catch (e) {
      debugPrint('Error importing graph: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  void _parseAndLoadGraph(List<dynamic> jsonList) {
    allNodes.clear();
    allLinks.clear();
    visibleNodes.clear();
    visibleLinks.clear();
    _expandedNodeIds.clear();
    _childPositionCache.clear();

    // 1. First pass: Create all nodes
    // The JSON structure is hierarchical (List of Roots, which have Children).
    // We need to flatten this into allNodes.

    for (final nodeJson in jsonList) {
      _parseNodeRecursive(nodeJson);
    }

    // 2. Second pass: Reconstruct Links from attachedNodeIds
    // Since attachedNodeIds are stored, we can rebuild links.
    // However, graph links are undirected edges stored distinctly.
    // To avoid duplicates (A-B and B-A), we can check existence.

    final processedPairs = <String>{};

    for (final node in allNodes.values) {
      for (final attachedId in node.attachedNodeIds) {
        if (!allNodes.containsKey(attachedId)) continue;

        // Create a unique key for the pair to check if link already exists
        final id1 = node.id.compareTo(attachedId) < 0 ? node.id : attachedId;
        final id2 = node.id.compareTo(attachedId) < 0 ? attachedId : node.id;
        final pairKey = '$id1-$id2';

        if (!processedPairs.contains(pairKey)) {
          allLinks.add(GraphLink(id1, id2));
          processedPairs.add(pairKey);
        }
      }

      // Recalculate connection count based on valid attached ID refs
      node.connectionCount = node.attachedNodeIds
          .where((id) => allNodes.containsKey(id))
          .length;
    }

    updateVisibility();
  }

  void _parseNodeRecursive(Map<String, dynamic> json) {
    // 1. Create the node itself
    final node = GraphNode.fromJson(json);
    allNodes[node.id] = node;

    // 2. Process children
    if (json.containsKey('children')) {
      final childrenJson = json['children'] as List<dynamic>;
      for (final childJson in childrenJson) {
        // Ensure child knows its parent (should be in JSON, but enforce it)
        childJson['parentId'] = node.id;
        _parseNodeRecursive(childJson as Map<String, dynamic>);

        // Ensure parent knows about child (GraphNode.fromJson initializes empty childrenIds)
        node.childrenIds.add(childJson['id'] as String);
      }
    }
  }
}
