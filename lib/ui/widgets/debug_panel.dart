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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(15.0, 25.0, 15.0, 0.0),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'DEBUG MENU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                activeThumbColor: Colors.amber,
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
                activeThumbColor: Colors.amber,
                onChanged: (val) {
                  debugService.showAllNodes.value = val;
                  // Trigger visibility update
                  graphService.updateVisibility();
                },
              );
            },
          ),

          const Divider(color: Colors.white24),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Actions',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await graphService.exportGraph();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Graph exported successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Export failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export Graph JSON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await graphService.importGraph();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Graph imported successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Import failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('Import Graph JSON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
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
                  builder: (context, _, child) {
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
