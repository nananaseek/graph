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
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('Double tap on node deselects it', (WidgetTester tester) async {
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

    // 3. Find target node (Use "Note A" which is at 100,100 initially)
    // Note: GraphScreen initializes with:
    // _addNode(const Offset(0, 0), "Main Hub");
    // _addNode(const Offset(100, 100), "Note A");
    final targetNode = painter.nodes.values.firstWhere(
      (n) => n.label == "Note A",
    );
    final targetPos = targetNode.position;
    print("Target Node Position: $targetPos");

    // 4. Double Tap to select
    // We need to convert logic coordinates to screen coordinates if needed.
    // In test, InteractiveViewer might be at scale 1.0, translation 400,300 (centered).
    // The nodes are in local coordinate space (0,0 is center of universe).
    // The Painter draws them relative to... wait.
    // GraphPainter receives `nodes` with their positions.
    // It draws them on the canvas.
    // The InteractiveViewer applies the transform.
    // So if we tap at `targetPos`, we are tapping in LOCAL coordinates.
    // But `tester.tapAt` expects GLOBAL coordinates.

    // We need to transform targetNode.position (local) to Global.
    final InteractiveViewer viewer = tester.widget(
      find.byType(InteractiveViewer),
    );
    final matrix = viewer.transformationController!.value;
    // Matrix is:
    // Scale 0 0 TransX
    // 0 Scale 0 TransY
    // ...
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    // Global = Local * Scale + Translation
    final globalPos =
        (targetPos * scale) + Offset(translation.x, translation.y);

    print("Global Tap Position: $globalPos");

    await tester.tapAt(globalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(globalPos);
    await tester.pumpAndSettle();

    // 5. Verify selection
    customPaint = tester.widget<CustomPaint>(customPaintFinder);
    painter = customPaint.painter as GraphPainter;
    expect(
      painter.selectedNodeId,
      equals(targetNode.id),
      reason: "Node should be selected after double tap",
    );

    // 6. Double tap to deselect
    await tester.tapAt(globalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(globalPos);
    await tester.pumpAndSettle();

    // 7. Verify deselection
    customPaint = tester.widget<CustomPaint>(customPaintFinder);
    painter = customPaint.painter as GraphPainter;
    expect(
      painter.selectedNodeId,
      isNull,
      reason: "Node should be deselected after double tap",
    );
  });
}
