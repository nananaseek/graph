import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:graph/ui/screens/graph_screen.dart';
import 'package:graph/logic/physics_engine.dart';
import 'package:graph/services/logging_service.dart';
import 'package:graph/models/graph_node.dart';
import 'package:graph/models/graph_link.dart';

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
  void startDrag(String id, [Offset? position]) {}

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
    print("Translation: $translation");
    print(
      "Screen Size: ${tester.binding.window.physicalSize / tester.binding.window.devicePixelRatio}",
    );

    // Standard test screen size is 800x600 in logical pixels.
    // Center of 800x600 is 400,300.
    expect(translation.x, equals(400.0));
    expect(translation.y, equals(300.0));
  });
}
