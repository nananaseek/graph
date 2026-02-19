import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../services/debug_service.dart';
import '../../services/graph_data_service.dart';

class DebugPanel extends StatelessWidget {
  final VoidCallback onClose;

  const DebugPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final debugService = getIt<DebugService>();
    final graphService = getIt<GraphDataService>();

    return Container(
      width: 280,
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'DEBUG MENU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),

          // Toggles
          ValueListenableBuilder<bool>(
            valueListenable: debugService.isEditMode,
            builder: (context, isEdit, _) {
              return SwitchListTile(
                title: const Text(
                  'Edit Mode',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Enable create/delete nodes',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: isEdit,
                activeColor: Colors.amber,
                onChanged: (val) => debugService.isEditMode.value = val,
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: debugService.showAllNodes,
            builder: (context, showAll, _) {
              return SwitchListTile(
                title: const Text(
                  'Show All Nodes',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Ignore visibility rules',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: showAll,
                activeColor: Colors.amber,
                onChanged: (val) {
                  debugService.showAllNodes.value = val;
                  // Trigger visibility update
                  graphService.updateVisibility();
                },
              );
            },
          ),

          const Divider(color: Colors.white24),

          // Stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Graph Stats',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: graphService.visibleTickNotifier,
                  builder: (context, _, __) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Nodes: ${graphService.allNodes.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Total Links: ${graphService.allLinks.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Visible Nodes: ${graphService.visibleNodes.length}',
                          style: const TextStyle(color: Colors.amber),
                        ),
                        Text(
                          'Visible Links: ${graphService.visibleLinks.length}',
                          style: const TextStyle(color: Colors.amber),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
