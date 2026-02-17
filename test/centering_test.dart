import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph/ui/screens/graph_screen.dart';

void main() {
  testWidgets('Canvas is centered on startup', (WidgetTester tester) async {
    // 1. Pump the widget
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));

    // 2. Wait for the post frame callback and layout (centering logic)
    await tester.pumpAndSettle();

    // 3. Find InteractiveViewer
    final interactiveViewerFinder = find.byType(InteractiveViewer);
    expect(interactiveViewerFinder, findsOneWidget);

    final InteractiveViewer viewer = tester.widget(interactiveViewerFinder);

    // We can't access `transformationController` directly from the widget
    // because it's passed into the state of InteractiveViewer or used within GraphScreen.
    // However, GraphScreen passes its OWN controller to InteractiveViewer.
    // So we can inspect the widget's controller if it exposes it,
    // OR we can find the TransformationController attached to it?
    // Actually GraphScreen creates the controller internally.

    // Checking the `transformationController` property of the found InteractiveViewer widget.
    expect(viewer.transformationController, isNotNull);

    final matrix = viewer.transformationController!.value;
    final translation = matrix.getTranslation();

    // 4. Verify translation
    // The screen size in test environment is usually 800x600 by default.
    // Center should be 400, 300.
    // We expect translation to be (400, 300, 0).

    print("Translation: $translation");

    // Standard test screen size is 800x600 in logical pixels.
    expect(translation.x, equals(400.0));
    expect(translation.y, equals(300.0));
  });
}
