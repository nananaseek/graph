import 'package:flutter/material.dart';
import 'ui/screens/graph_screen.dart';

import 'core/service_locator.dart';

void main() {
  setupServiceLocator();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: GraphScreen()),
  );
}
