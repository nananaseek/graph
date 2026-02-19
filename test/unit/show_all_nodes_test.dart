import 'package:flutter_test/flutter_test.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/services/graph_data_service.dart';
import 'package:graph/services/debug_service.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/material.dart';

void main() {
  late GraphDataService graphDataService;
  late DebugService debugService;

  setUp(() {
    GetIt.I.reset();
    debugService = DebugService();
    GetIt.I.registerSingleton<DebugService>(debugService);

    graphDataService = GraphDataService();
    GetIt.I.registerSingleton<GraphDataService>(graphDataService);
  });

  test('Show All Nodes toggle forces all nodes to be visible', () {
    // Setup: Root -> Child -> SubChild
    // Normal visibility: Root visible. Child visible if Root focused. SubChild visible if Child focused.
    // Show All: All visible.

    final root = GraphNode(
      id: 'root',
      position: Offset.zero,
      label: 'Root',
      selfGeneratedMoney: 0,
    );
    final child = GraphNode(
      id: 'child',
      position: Offset.zero,
      label: 'Child',
      selfGeneratedMoney: 0,
      parentId: 'root',
    );
    final subChild = GraphNode(
      id: 'sub',
      position: Offset.zero,
      label: 'Sub',
      selfGeneratedMoney: 0,
      parentId: 'child',
    );

    graphDataService.allNodes['root'] = root;
    graphDataService.allNodes['child'] = child;
    graphDataService.allNodes['sub'] = subChild;

    // Initial state (default focus null): Only roots visible
    graphDataService.updateVisibility();
    expect(graphDataService.visibleNodes.containsKey('root'), true);
    expect(graphDataService.visibleNodes.containsKey('child'), false);
    expect(graphDataService.visibleNodes.containsKey('sub'), false);

    // Enable Show All
    debugService.showAllNodes.value = true;
    graphDataService.updateVisibility();

    expect(graphDataService.visibleNodes.containsKey('root'), true);
    expect(graphDataService.visibleNodes.containsKey('child'), true);
    expect(graphDataService.visibleNodes.containsKey('sub'), true);

    // Disable Show All
    debugService.showAllNodes.value = false;
    graphDataService.updateVisibility();

    // Should revert to normal rules
    expect(graphDataService.visibleNodes.containsKey('root'), true);
    expect(graphDataService.visibleNodes.containsKey('child'), false);
    expect(graphDataService.visibleNodes.containsKey('sub'), false);
  });
}
