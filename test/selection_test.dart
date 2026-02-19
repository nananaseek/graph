import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:graph/ui/screens/graph_screen.dart';
import 'package:graph/ui/painters/graph_painter.dart';
import 'package:graph/logic/physics_engine.dart';
import 'package:graph/services/logging_service.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/models/graph_link.dart';
import 'package:graph/services/graph_data_service.dart';
import 'package:graph/services/selected_node_service.dart';
import 'package:graph/services/camera_service.dart';

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
  void initMockData() {
    allNodes.clear();
    visibleNodes.clear();

    final node = GraphNode(
      id: "node1",
      position: const Offset(100, 100),
      name: "Master Node 1",
      label: "Master Node 1",
      mass: 30,
      radius: 20,
      appearanceScale: 1.0,
    );

    allNodes[node.id] = node;
    visibleNodes[node.id] = node;
    visibleTickNotifier.value++;
  }

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
  void addNode(GraphNode node) {}

  @override
  void updateVisibility() {}
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<PhysicsEngine>(FakePhysicsEngine());
    getIt.registerSingleton<LoggingService>(FakeLoggingService());
    getIt.registerSingleton<GraphDataService>(FakeGraphDataService());
    getIt.registerSingleton<SelectedNodeService>(SelectedNodeService());
    getIt.registerSingleton<CameraService>(CameraService());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('Double tap on node selects it', (WidgetTester tester) async {
    // 1. Pump the widget
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));

    // Allow initial layout
    await tester.pumpAndSettle();

    // 2. Find GraphPainter to get node locations
    final customPaintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GraphPainter,
    );

    expect(
      customPaintFinder,
      findsOneWidget,
      reason: "Should find exactly one GraphPainter",
    );

    var customPaint = tester.widget<CustomPaint>(customPaintFinder);
    var painter = customPaint.painter as GraphPainter;

    expect(painter.nodes, isNotEmpty, reason: "Nodes should be initialized");

    // 3. Find target node
    final targetNode = painter.nodes.values.firstWhere(
      (n) => n.name == "Master Node 1",
    );
    final targetPos = targetNode.position;

    // 4. Transform to global coordinates for tap
    final InteractiveViewer viewer = tester.widget(
      find.byType(InteractiveViewer),
    );
    final matrix = viewer.transformationController!.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final globalPos =
        (targetPos * scale) + Offset(translation.x, translation.y);

    // 5. Double Tap to select
    await tester.tapAt(globalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(globalPos);
    await tester.pumpAndSettle();

    // 6. Verify selection
    final selectedNodeService = GetIt.instance<SelectedNodeService>();
    expect(
      selectedNodeService.selectedNodeId.value,
      equals(targetNode.id),
      reason: "Node should be selected after double tap",
    );

    // Also verify focus was set (mock service)
    final graphDataService = GetIt.instance<GraphDataService>();
    expect(
      graphDataService.focusedNodeId.value,
      equals(targetNode.id),
      reason: "Focus should be set after double tap",
    );
  });
}
