import 'package:flutter/foundation.dart';

/// Manages the currently selected node and navigation stack for drill-down.
class SelectedNodeService {
  /// Currently selected node ID (null = no selection / root list view).
  final ValueNotifier<String?> selectedNodeId = ValueNotifier(null);

  /// Navigation stack for drill-down in the side panel.
  /// Each entry is a node ID. The last entry is the currently viewed node.
  final ValueNotifier<List<String>> navigationStack = ValueNotifier([]);

  /// Notifier that fires when the side panel should open.
  final ValueNotifier<bool> isSidePanelOpen = ValueNotifier(false);

  /// Select a node — pushes it onto the navigation stack.
  void selectNode(String id) {
    final stack = List<String>.from(navigationStack.value);
    // Don't push duplicates at the top
    if (stack.isEmpty || stack.last != id) {
      stack.add(id);
    }
    navigationStack.value = stack;
    selectedNodeId.value = id;
  }

  /// Navigate back one level in the drill-down.
  void navigateBack() {
    final stack = List<String>.from(navigationStack.value);
    if (stack.isNotEmpty) {
      stack.removeLast();
    }
    navigationStack.value = stack;
    selectedNodeId.value = stack.isNotEmpty ? stack.last : null;
  }

  /// Clear all selection and navigation.
  void clearSelection() {
    navigationStack.value = [];
    selectedNodeId.value = null;
  }

  /// Open the side panel.
  void openPanel() {
    isSidePanelOpen.value = true;
  }

  /// Close the side panel and clear selection.
  void closePanel() {
    isSidePanelOpen.value = false;
    clearSelection();
  }

  /// Toggle the side panel.
  void togglePanel() {
    if (isSidePanelOpen.value) {
      closePanel();
    } else {
      openPanel();
    }
  }

  void dispose() {
    selectedNodeId.dispose();
    navigationStack.dispose();
    isSidePanelOpen.dispose();
  }
}
