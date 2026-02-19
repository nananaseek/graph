import 'package:flutter/foundation.dart';

/// Service to manage debug flags and edit mode state.
class DebugService {
  /// Whether the app is in "Edit Mode".
  /// In Edit Mode, CRUD buttons (Create, Delete) are visible.
  final ValueNotifier<bool> isEditMode = ValueNotifier(false);

  /// Whether to bypass visibility rules and show ALL nodes.
  final ValueNotifier<bool> showAllNodes = ValueNotifier(false);

  void toggleEditMode() {
    isEditMode.value = !isEditMode.value;
  }

  void toggleShowAllNodes() {
    showAllNodes.value = !showAllNodes.value;
  }
}
