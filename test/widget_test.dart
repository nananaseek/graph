// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:graph/ui/screens/graph_screen.dart';
import 'package:graph/logic/physics_engine.dart';
import 'package:graph/services/logging_service.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/models/graph_link.dart';
import 'package:graph/services/graph_data_service.dart';
import 'package:graph/services/selected_node_service.dart';
import 'package:graph/services/camera_service.dart';
import 'package:graph/services/debug_service.dart';

// Fake Classes (minimal implementation for smoke test)
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
  void startDrag(String id, [Offset? position]) {}

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
    getIt.registerSingleton<DebugService>(DebugService());
  });

  tearDown(() {
    GetIt.instance.reset();
  });
  testWidgets('Graph app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));

    // Verify that the graph screen is present.
    expect(find.byType(GraphScreen), findsOneWidget);

    // Tap the menu button to open sidebar
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(seconds: 1));

    // Verify sidebar text is visible
    expect(find.text('Твої реферали'), findsOneWidget);
  });
}
