import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:graph/ui/screens/graph_screen.dart';
import 'package:graph/ui/widgets/graph_renderer.dart';
import 'package:graph/logic/physics_engine.dart';
import 'package:graph/services/logging_service.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/models/graph_link.dart';
import 'package:graph/services/graph_data_service.dart';
import 'package:graph/services/selected_node_service.dart';
import 'package:graph/services/camera_service.dart';

// Fake Classes
class FakePhysicsEngine implements PhysicsEngine {
  @override
  Stream<Map<String, Offset>> get onUpdate => const Stream.empty();

  @override
  Future<void> init(
    Map<String, GraphNode>? nodes,
    List<GraphLink>? links,
  ) async {}

  @override
  void addNode(GraphNode? node) {}

  @override
  void updateLinks(List<GraphLink>? links) {}

  @override
  void updateNodes(List<GraphNode>? nodes) {}

  @override
  void dispose() {}

  @override
  void endDrag() {}

  @override
  void reheat() {}

  @override
  void removeNode(String id) {}

  @override
  void startDrag(String id) {}

  @override
  void updateNodePosition(String id, Offset position) {}

  @override
  void setGraph(Map<String, GraphNode> nodes, List<GraphLink> links) {}
}

class FakeLoggingService implements LoggingService {
  @override
  void logNodeCreation(String? id) {}

  @override
  void logNodeDeletion(String? id) {}

  @override
  void logLinkCreation(String sourceId, String targetId) {}

  @override
  void logNodeDeselection(String id) {}

  @override
  void logNodeDragEnd(String id) {}

  @override
  void logNodeDragStart(String id) {}

  @override
  void logNodeSelection(String id) {}
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<PhysicsEngine>(FakePhysicsEngine());
    getIt.registerSingleton<LoggingService>(FakeLoggingService());
    getIt.registerSingleton<GraphDataService>(GraphDataService());
    getIt.registerSingleton<SelectedNodeService>(SelectedNodeService());
    getIt.registerSingleton<CameraService>(CameraService());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('GraphRenderer viewport updates on pan', (
    WidgetTester tester,
  ) async {
    // 1. Pump the widget
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));
    await tester.pumpAndSettle();

    // 2. Find GraphRenderer and get initial viewport
    final rendererFinder = find.byType(GraphRenderer);
    expect(rendererFinder, findsOneWidget);

    final GraphRenderer initialRenderer = tester.widget(rendererFinder);
    final initialViewport = initialRenderer.viewport;
    print("Initial Viewport: $initialViewport");

    // 3. Find InteractiveViewer and pan
    final viewerFinder = find.byType(InteractiveViewer);
    expect(viewerFinder, findsOneWidget);

    // Drag by (100, 100)
    await tester.drag(viewerFinder, const Offset(100, 100));
    await tester.pump(); // Pump frame

    // 4. Get viewport again
    final GraphRenderer updatedRenderer = tester.widget(rendererFinder);
    final updatedViewport = updatedRenderer.viewport;
    print("Updated Viewport: $updatedViewport");

    // 5. Assert viewport has changed
    // If the bug exists, these will be equal because GraphScreen didn't rebuild
    expect(
      updatedViewport,
      isNot(equals(initialViewport)),
      reason: "Viewport should change after panning",
    );

    // Clear pending timers
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
