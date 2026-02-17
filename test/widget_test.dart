// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph/ui/screens/graph_screen.dart';

void main() {
  testWidgets('Graph app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: GraphScreen()));

    // Verify that the graph screen is present.
    expect(find.byType(GraphScreen), findsOneWidget);

    // Tap the menu button to open sidebar
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(seconds: 1));

    // Verify sidebar text is visible
    expect(find.text('Твої Графи'), findsOneWidget);
  });
}
