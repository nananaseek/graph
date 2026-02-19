import 'package:flutter_test/flutter_test.dart';
import 'package:graph/services/graph_data_service.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/models/graph_link.dart';

void main() {
  group('GraphDataService Visibility Logic', () {
    late GraphDataService service;

    setUp(() {
      service = GraphDataService();
      // Manually populate with a known structure
      // Root1
      //   - Child1_1
      //      - Child1_1_1
      //   - Child1_2
      // Root2

      final root1 = GraphNode(
        id: 'root1',
        position: Offset.zero,
        label: 'Root 1',
      );
      final root2 = GraphNode(
        id: 'root2',
        position: Offset.zero,
        label: 'Root 2',
      );

      final child1_1 = GraphNode(
        id: 'child1_1',
        position: Offset.zero,
        label: 'Child 1.1',
        parentId: 'root1',
      );
      root1.childrenIds.add('child1_1');

      final child1_2 = GraphNode(
        id: 'child1_2',
        position: Offset.zero,
        label: 'Child 1.2',
        parentId: 'root1',
      );
      root1.childrenIds.add('child1_2');

      final child1_1_1 = GraphNode(
        id: 'child1_1_1',
        position: Offset.zero,
        label: 'Child 1.1.1',
        parentId: 'child1_1',
      );
      child1_1.childrenIds.add('child1_1_1');

      service.allNodes['root1'] = root1;
      service.allNodes['root2'] = root2;
      service.allNodes['child1_1'] = child1_1;
      service.allNodes['child1_2'] = child1_2;
      service.allNodes['child1_1_1'] = child1_1_1;

      // Add links
      service.allLinks.add(GraphLink('root1', 'child1_1'));
      service.allLinks.add(GraphLink('root1', 'child1_2'));
      service.allLinks.add(GraphLink('child1_1', 'child1_1_1'));

      service.updateVisibility();
    });

    test('Initial state: Only roots should be visible', () {
      // Must trigger visibility update manually or init
      // Since we manually populated, let's call setFocus(null) to trigger update or expose _updateVisibility if needed.
      // But setFocus(null) should act as reset.
      service.setFocus(null);

      expect(
        service.visibleNodes.containsKey('root1'),
        isTrue,
        reason: 'Root 1 should be visible',
      );
      expect(
        service.visibleNodes.containsKey('root2'),
        isTrue,
        reason: 'Root 2 should be visible',
      );
      expect(
        service.visibleNodes.containsKey('child1_1'),
        isFalse,
        reason: 'Child 1.1 should NOT be visible',
      );
      expect(
        service.visibleNodes.containsKey('child1_1_1'),
        isFalse,
        reason: 'Child 1.1.1 should NOT be visible',
      );
    });

    test('Focus on Root: Root + Children visible', () {
      service.setFocus('root1');

      expect(service.visibleNodes.containsKey('root1'), isTrue);
      expect(
        service.visibleNodes.containsKey('root2'),
        isTrue,
        reason: 'Other roots stay visible',
      );

      expect(
        service.visibleNodes.containsKey('child1_1'),
        isTrue,
        reason: 'Child 1.1 should be visible',
      );
      expect(
        service.visibleNodes.containsKey('child1_2'),
        isTrue,
        reason: 'Child 1.2 should be visible',
      );

      expect(
        service.visibleNodes.containsKey('child1_1_1'),
        isFalse,
        reason: 'Grandchild should NOT be visible yet',
      );
    });

    test('Focus on Child: Roots + Ancestors + Children visible', () {
      service.setFocus('child1_1');

      // Roots
      expect(
        service.visibleNodes.containsKey('root1'),
        isTrue,
        reason: 'Root 1 (Ancestor) must be visible',
      );
      expect(
        service.visibleNodes.containsKey('root2'),
        isTrue,
        reason: 'Root 2 (Other root) must be visible',
      );

      // Ancestor path
      expect(
        service.visibleNodes.containsKey('child1_1'),
        isTrue,
        reason: 'Focused node visible',
      );

      // Children of focus
      expect(
        service.visibleNodes.containsKey('child1_1_1'),
        isTrue,
        reason: 'Child of focused node visible',
      );

      // Siblings of active path?
      // Rule: Active Path visible. Child1_2 is sibling of Child1_1.
      // Is Child1_2 in active path? No.
      // Is Child1_2 a child of focus? No.
      // So Child1_2 should be HIDDEN.
      expect(
        service.visibleNodes.containsKey('child1_2'),
        isFalse,
        reason: 'Sibling not in active path should be hidden',
      );
    });

    test('Switch focus from Child to Root: Hides deep descendants', () {
      // First focus deep
      service.setFocus('child1_1');
      expect(service.visibleNodes.containsKey('child1_1_1'), isTrue);

      // Switch focus back to root
      service.setFocus('root1');

      expect(
        service.visibleNodes.containsKey('child1_1_1'),
        isFalse,
        reason: 'Deep descendant should hide',
      );
      expect(
        service.visibleNodes.containsKey('child1_1'),
        isTrue,
        reason: 'Direct child of new focus',
      );
      expect(
        service.visibleNodes.containsKey('child1_2'),
        isTrue,
        reason: 'Direct child of new focus',
      );
    });
  });
}
