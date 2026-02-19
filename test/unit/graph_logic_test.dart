import 'package:flutter_test/flutter_test.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/services/graph_data_service.dart';

import 'package:get_it/get_it.dart';
import 'package:graph/services/debug_service.dart'; // Import DebugService if needed for service locator

void main() {
  late GraphDataService graphDataService;

  setUp(() {
    GetIt.I.reset();
    // Register dependencies
    GetIt.I.registerSingleton<DebugService>(DebugService());
    graphDataService = GraphDataService();
    GetIt.I.registerSingleton<GraphDataService>(graphDataService);
  });

  group('Money Calculation', () {
    test('totalGeneratedMoney sums self + children', () {
      final root = GraphNode(
        id: 'root',
        position: const Offset(0, 0),
        label: 'Root',
        selfGeneratedMoney: 100,
      );
      final child1 = GraphNode(
        id: 'c1',
        position: const Offset(0, 0),
        label: 'C1',
        selfGeneratedMoney: 50,
      );
      final child2 = GraphNode(
        id: 'c2',
        position: const Offset(0, 0),
        label: 'C2',
        selfGeneratedMoney: 25,
      );

      graphDataService.allNodes['root'] = root;
      graphDataService.allNodes['c1'] = child1;
      graphDataService.allNodes['c2'] = child2;

      root.childrenIds.add('c1');
      child1.childrenIds.add('c2'); // Hierarchy: Root -> C1 -> C2

      // Verify
      expect(child2.totalGeneratedMoney, 25);
      expect(child1.totalGeneratedMoney, 50 + 25);
      expect(root.totalGeneratedMoney, 100 + 50 + 25);
    });

    test('updates reflected immediately', () {
      final root = GraphNode(
        id: 'root',
        position: const Offset(0, 0),
        label: 'R',
        selfGeneratedMoney: 10,
      );
      final child = GraphNode(
        id: 'c1',
        position: const Offset(0, 0),
        label: 'C',
        selfGeneratedMoney: 5,
      );

      graphDataService.allNodes['root'] = root;
      graphDataService.allNodes['c1'] = child;
      root.childrenIds.add('c1');

      expect(root.totalGeneratedMoney, 15);

      // Update child money
      child.selfGeneratedMoney = 20;
      expect(root.totalGeneratedMoney, 30);
    });
  });

  group('CRUD Operations', () {
    test('createRootNode adds a master node', () {
      final initialCount = graphDataService.allNodes.length;
      graphDataService.createRootNode();
      expect(graphDataService.allNodes.length, initialCount + 1);

      final newNode = graphDataService.allNodes.values.last;
      expect(newNode.label, 'New Root');
      expect(newNode.parentId, null);
      // Should be in visible nodes (roots always visible)
      expect(graphDataService.visibleNodes.containsKey(newNode.id), true);
    });

    test('createSlaveNode adds a child', () {
      graphDataService.createRootNode();
      final root = graphDataService.allNodes.values.last;

      graphDataService.createSlaveNode(root.id);

      expect(root.childrenIds.length, 1);
      final childId = root.childrenIds.first;
      final child = graphDataService.allNodes[childId];

      expect(child, isNotNull);
      expect(child!.parentId, root.id);
    });

    test('deleteNode removes subtree', () {
      // Setup: Root -> C1 -> C2
      final root = GraphNode(
        id: 'root',
        position: const Offset(0, 0),
        label: 'R',
        selfGeneratedMoney: 0,
      );
      final c1 = GraphNode(
        id: 'c1',
        position: const Offset(0, 0),
        label: 'C1',
        selfGeneratedMoney: 0,
        parentId: 'root',
      );
      final c2 = GraphNode(
        id: 'c2',
        position: const Offset(0, 0),
        label: 'C2',
        selfGeneratedMoney: 0,
        parentId: 'c1',
      );

      graphDataService.allNodes['root'] = root;
      graphDataService.allNodes['c1'] = c1;
      graphDataService.allNodes['c2'] = c2;

      root.childrenIds.add('c1');
      c1.childrenIds.add('c2');

      // Delete C1 (should remove C1 and C2, keep Root)
      graphDataService.deleteNode('c1');

      expect(graphDataService.allNodes.containsKey('root'), true);
      expect(graphDataService.allNodes.containsKey('c1'), false);
      expect(graphDataService.allNodes.containsKey('c2'), false);

      expect(root.childrenIds.contains('c1'), false);
    });
  });
}
