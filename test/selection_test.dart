import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph/ui/screens/graph_screen.dart';
import 'package:graph/ui/painters/graph_painter.dart';

void main() {
  testWidgets('Double tap on node deselects it', (WidgetTester tester) async {
    // 1. Pump the widget
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));

    // Allow initial layout and physics init (if any)
    await tester.pump(const Duration(milliseconds: 100));

    // 2. Find GraphPainter to get node locations
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
    final targetNode = painter.nodes.values.firstWhere(
      (n) => n.label == "Note A",
    );
    final targetPos = targetNode.position;
    print("Target Node Position: $targetPos"); // Debug print

    // 4. Tap to select
    // Assuming initial scroll is 0,0 and scale is 1.0.
    // InteractiveViewer with large content starts at 0,0 usually.
    // We tap at the node's position.
    // Add a small offset to ensure we hit the circle if it's centered?
    // GraphPainter draws circle AT the position. So tapping AT position should work.
    // However, we need to match the coordinate system.
    // The CustomPaint is inside InteractiveViewer -> SizedBox.
    // The tap must be in global screen coordinates.
    // If CustomPaint is at 0,0 of the screen, then targetPos is correct.

    // 4. Double Tap to select (Current implementation requires double tap to select)
    await tester.tapAt(targetPos);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(targetPos);
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
    // A double tap is two taps in quick succession.
    // flutter_test doesn't have a direct 'doubleTapAt' that guarantees the existing state isn't reset?
    // actually tester.tapAt twice with small delay.

    // But `GestureDetector` double tap logic:
    // It detects double tap if second tap follows quickly.
    // `tester.tap` sends a down/up pair.

    // First tap of the double tap sequence:
    await tester.tapAt(targetPos);
    await tester.pump(const Duration(milliseconds: 50)); // Small delay
    await tester.tapAt(targetPos); // Second tap
    await tester.pumpAndSettle(); // Allow double tap callback to fire

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
