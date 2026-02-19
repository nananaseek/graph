import 'dart:async';
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

// Fake Classes
class FakePhysicsEngine implements PhysicsEngine {
  final _controller = StreamController<Map<String, Offset>>.broadcast();

  @override
  Stream<Map<String, Offset>> get onUpdate => _controller.stream;

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
  void dispose() {
    _controller.close();
  }

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

class FakeGraphDataService implements GraphDataService {
  @override
  final Map<String, GraphNode> allNodes = {};
  @override
  final ValueNotifier<int> visibleTickNotifier = ValueNotifier(0);
  @override
  final Map<String, GraphNode> visibleNodes = {};
  @override
  final ValueNotifier<String?> focusedNodeId = ValueNotifier(null);
  @override
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  @override
  GraphNode? getParent(String nodeId) => null;

  @override
  void setFocus(String? nodeId) {
    focusedNodeId.value = nodeId;
  }

  @override
  List<GraphNode> get masterNodes => allNodes.values.toList();

  @override
  GraphNode? getNode(String id) => allNodes[id];

  @override
  List<GraphNode> getChildren(String parentId) => [];

  @override
  List<GraphLink> get visibleLinks => [];

  @override
  List<GraphLink> get allLinks => [];

  @override
  void updateVisibility() {}

  @override
  void createRootNode() {}

  @override
  void createSlaveNode(String parentId) {}

  @override
  void deleteNode(String nodeId) {}

  @override
  void updateNode(String nodeId, {String? name, double? money}) {}

  @override
  Future<void> loadDemoData() async {}

  @override
  Future<void> exportGraph() async {}

  @override
  Future<void> importGraph() async {}
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<PhysicsEngine>(FakePhysicsEngine());
    getIt.registerSingleton<LoggingService>(FakeLoggingService());
    getIt.registerSingleton<GraphDataService>(FakeGraphDataService());
    getIt.registerSingleton<SelectedNodeService>(SelectedNodeService());
    getIt.registerSingleton<CameraService>(CameraService());
    getIt.registerSingleton<DebugService>(DebugService());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('Canvas is centered on startup', (WidgetTester tester) async {
    // 1. Pump the widget
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));

    // 2. Wait for the post frame callback and layout (centering logic)
    await tester.pumpAndSettle();

    // 3. Find InteractiveViewer
    final interactiveViewerFinder = find.byType(InteractiveViewer);
    expect(interactiveViewerFinder, findsOneWidget);

    final InteractiveViewer viewer = tester.widget(interactiveViewerFinder);

    // Checking the `transformationController` property of the found InteractiveViewer widget.
    expect(viewer.transformationController, isNotNull);

    final matrix = viewer.transformationController!.value;
    final translation = matrix.getTranslation();

    // 4. Verify translation
    // 4. Verify translation

    // Standard test screen size is 800x600 in logical pixels.
    // Center of 800x600 is 400,300.
    expect(translation.x, equals(400.0));
    expect(translation.y, equals(300.0));
  });
}
