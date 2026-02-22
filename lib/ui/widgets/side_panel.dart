import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../services/graph_data_service.dart';
import '../../services/selected_node_service.dart';
import '../../services/camera_service.dart';
import '../../models/graph_node.dart';

/// Side panel widget with drill-down navigation.
///
/// Fully isolated from the canvas — uses its own ValueListenableBuilders
/// and never triggers canvas repaints.
class SidePanel extends StatelessWidget {
  final double screenWidth;

  const SidePanel({super.key, required this.screenWidth});

  // Screen size cached from parent - kept here for easy access by _onNodeTap
  static Size? _cachedScreenSize;

  static void updateScreenSize(Size size) {
    _cachedScreenSize = size;
  }

  @override
  Widget build(BuildContext context) {
    final selectedNodeService = getIt<SelectedNodeService>();
    final isMobile = screenWidth < 600;
    final panelWidth = screenWidth * (isMobile ? 0.7 : 0.35);

    return ValueListenableBuilder<bool>(
      valueListenable: selectedNodeService.isSidePanelOpen,
      builder: (context, isOpen, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          left: isOpen ? 0 : -panelWidth,
          width: panelWidth,
          child: Material(
            color: const Color.fromRGBO(20, 52, 63, 0.97),
            elevation: 10,
            child: SafeArea(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: selectedNodeService.navigationStack,
                builder: (context, stack, _) {
                  return _PanelContent(stack: stack);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PanelContent extends StatelessWidget {
  final List<String> stack;

  const _PanelContent({required this.stack});

  @override
  Widget build(BuildContext context) {
    final graphDataService = getIt<GraphDataService>();
    final selectedNodeService = getIt<SelectedNodeService>();

    // Root level — show master nodes list
    if (stack.isEmpty) {
      return _buildRootView(graphDataService, selectedNodeService);
    }

    // Drill-down — show selected node details
    final currentNodeId = stack.last;
    final currentNode = graphDataService.getNode(currentNodeId);
    if (currentNode == null) {
      return _buildRootView(graphDataService, selectedNodeService);
    }

    return _buildNodeDetailView(
      currentNode,
      graphDataService,
      selectedNodeService,
    );
  }

  Widget _buildRootView(GraphDataService gds, SelectedNodeService sns) {
    final masters = gds.masterNodes;
    return Column(
      children: [
        _buildHeader(title: 'Твої ноди', onClose: () => sns.closePanel()),
        const Divider(color: Colors.white24),
        Expanded(
          child: ListView.builder(
            itemCount: masters.length,
            itemBuilder: (context, index) {
              final node = masters[index];
              return _NodeListTile(
                node: node,
                onTap: () => _onNodeTap(node, sns),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNodeDetailView(
    GraphNode node,
    GraphDataService gds,
    SelectedNodeService sns,
  ) {
    final children = gds.getChildren(node.id);

    return Column(
      children: [
        _buildHeader(
          title: node.name,
          onClose: () => sns.closePanel(),
          onBack: () => sns.navigateBack(),
        ),
        const Divider(color: Colors.white24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 12),
              // Node info card
              _InfoCard(node: node),
              const SizedBox(height: 20),
              // Slave nodes section
              if (children.isNotEmpty) ...[
                const Text(
                  'Підпорядковані ноди',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...children.map(
                  (child) => _NodeListTile(
                    node: child,
                    onTap: () => _onNodeTap(child, sns),
                  ),
                ),
              ],
              if (children.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text(
                      'Немає підпорядкованих нод',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required String title,
    required VoidCallback onClose,
    VoidCallback? onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (onBack != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  void _onNodeTap(GraphNode node, SelectedNodeService sns) {
    sns.selectNode(node.id);

    // Animate camera to the node
    final cameraService = getIt<CameraService>();
    final graphDataService = getIt<GraphDataService>();
    final visibleNode = graphDataService.visibleNodes[node.id];
    if (visibleNode != null) {
      // Use cached screen size from SidePanel static member
      final screenSize = SidePanel._cachedScreenSize;
      if (screenSize != null) {
        cameraService.animateTo(
          visibleNode.position,
          visibleNode.radius,
          screenSize,
        );
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final GraphNode node;

  const _InfoCard({required this.node});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF80cde3).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF80cde3).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            Icons.monetization_on,
            'Згенеровані гроші',
            '${node.generatedMoney.toStringAsFixed(0)} ₴',
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.link, 'Зв\'язки', '${node.connectionCount}'),
          const SizedBox(height: 12),
          _infoRow(
            Icons.account_tree,
            'Підпорядковані',
            '${node.childrenIds.length}',
          ),
          if (node.attachedNodeIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(
              Icons.attach_file,
              'Прикріплені',
              '${node.attachedNodeIds.length}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF80cde3), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NodeListTile extends StatelessWidget {
  final GraphNode node;
  final VoidCallback onTap;

  const _NodeListTile({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        node.childrenIds.isNotEmpty ? Icons.hub : Icons.circle,
        color: const Color(0xFF80cde3),
        size: 16,
      ),
      title: Text(node.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '${node.generatedMoney.toStringAsFixed(0)} ₴  •  ${node.childrenIds.length} slave',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: node.childrenIds.isNotEmpty
          ? const Icon(Icons.chevron_right, color: Colors.white38, size: 20)
          : null,
      onTap: onTap,
      dense: true,
    );
  }
}
