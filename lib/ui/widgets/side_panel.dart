import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../services/graph_data_service.dart';
import '../../services/selected_node_service.dart';
import '../../services/camera_service.dart';
import '../../services/debug_service.dart';
import '../../models/graph_node.dart';

class SidePanel extends StatelessWidget {
  final double screenWidth;

  const SidePanel({super.key, required this.screenWidth});

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
  @override
  Widget build(BuildContext context) {
    final graphDataService = getIt<GraphDataService>();
    final selectedNodeService = getIt<SelectedNodeService>();
    final debugService = getIt<DebugService>();

    return ValueListenableBuilder<bool>(
      valueListenable: debugService.isEditMode,
      builder: (context, isEditMode, _) {
        // Root level — show master nodes list
        if (stack.isEmpty) {
          return _buildRootView(
            graphDataService,
            selectedNodeService,
            isEditMode,
          );
        }

        final currentNodeId = stack.last;
        final currentNode = graphDataService.getNode(currentNodeId);
        if (currentNode == null) {
          return _buildRootView(
            graphDataService,
            selectedNodeService,
            isEditMode,
          );
        }

        return _buildNodeDetailView(
          context,
          currentNode,
          graphDataService,
          selectedNodeService,
          isEditMode,
        );
      },
    );
  }

  Widget _buildRootView(
    GraphDataService gds,
    SelectedNodeService sns,
    bool isEditMode,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: gds.visibleTickNotifier,
      builder: (context, _, __) {
        final masters = gds.masterNodes;
        final totalNodes = gds.allNodes.length;
        final totalMoney = gds.allNodes.values.fold(
          0.0,
          (sum, node) => sum + node.selfGeneratedMoney,
        );

        return Column(
          children: [
            _buildHeader(
              title: 'Твої ноди',
              onClose: () => sns.closePanel(),
              trailing: isEditMode
                  ? IconButton(
                      icon: const Icon(Icons.add, color: Colors.amber),
                      tooltip: 'Create Root Node',
                      onPressed: () => gds.createRootNode(),
                    )
                  : null,
            ),
            _GlobalStatsCard(totalNodes: totalNodes, totalMoney: totalMoney),
            const Divider(color: Colors.white24, height: 1),
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
      },
    );
  }

  Widget _buildNodeDetailView(
    BuildContext context,
    GraphNode node,
    GraphDataService gds,
    SelectedNodeService sns,
    bool isEditMode,
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
              if (isEditMode)
                _NodeEditor(node: node, onUpdate: gds.updateNode)
              else
                _InfoCard(node: node),

              const SizedBox(height: 20),

              if (isEditMode) ...[
                _buildActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Create Slave Node',
                  color: Colors.amber,
                  onTap: () => gds.createSlaveNode(node.id),
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete Node',
                  color: Colors.redAccent,
                  onTap: () {
                    _showDeleteConfirm(context, node, gds, sns);
                  },
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
              ],

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
    Widget? trailing,
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
          // ignore: use_null_aware_elements
          if (trailing != null) trailing,
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
        cameraService.animateTo(visibleNode.position, screenSize);
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    GraphNode node,
    GraphDataService gds,
    SelectedNodeService sns,
  ) {
    final hasChildren = node.childrenIds.isNotEmpty;

    if (!hasChildren) {
      sns.navigateBack();
      gds.deleteNode(node.id);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'Delete Node?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This node has ${node.childrenIds.length} children. Deleting it will also delete all descendants.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              sns.navigateBack();
              gds.deleteNode(node.id);
            },
          ),
        ],
      ),
    );
  }
}

class _GlobalStatsCard extends StatelessWidget {
  final int totalNodes;
  final double totalMoney;

  const _GlobalStatsCard({required this.totalNodes, required this.totalMoney});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
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
          _infoRow(Icons.account_tree, 'Всього нод', '$totalNodes'),
          const SizedBox(height: 12),
          _infoRow(
            Icons.monetization_on,
            'Загальний прибуток',
            '${totalMoney.toStringAsFixed(0)} ₴',
          ),
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

class _InfoCard extends StatelessWidget {
  final GraphNode node;

  const _InfoCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final gds = getIt<GraphDataService>();
    final descendantsMoney = gds.getDescendantsMoney(node.id);
    final totalMoney = node.selfGeneratedMoney + descendantsMoney;

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
            'Власний прибуток',
            '${node.selfGeneratedMoney.toStringAsFixed(0)} ₴',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.people_alt,
            'Від мережі (slave)',
            '${descendantsMoney.toStringAsFixed(0)} ₴',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.account_balance_wallet,
            'Загалом гілка',
            '${totalMoney.toStringAsFixed(0)} ₴',
          ),
          const Divider(color: Colors.white24, height: 24),
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
    final gds = getIt<GraphDataService>();
    final totalMoney =
        node.selfGeneratedMoney + gds.getDescendantsMoney(node.id);

    return ListTile(
      leading: Icon(
        node.childrenIds.isNotEmpty ? Icons.hub : Icons.circle,
        color: const Color(0xFF80cde3),
        size: 16,
      ),
      title: Text(node.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '${totalMoney.toStringAsFixed(0)} ₴  •  ${node.childrenIds.length} slave',
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

class _NodeEditor extends StatefulWidget {
  final GraphNode node;
  final Function(String, {String? name, double? money}) onUpdate;

  const _NodeEditor({required this.node, required this.onUpdate});

  @override
  State<_NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends State<_NodeEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _moneyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.node.name);
    _moneyCtrl = TextEditingController(
      text: widget.node.selfGeneratedMoney.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_NodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _nameCtrl.text = widget.node.name;
      _moneyCtrl.text = widget.node.selfGeneratedMoney.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _moneyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text;
    final money =
        double.tryParse(_moneyCtrl.text) ?? widget.node.selfGeneratedMoney;
    widget.onUpdate(widget.node.id, name: name, money: money);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EDIT NODE',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _moneyCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Self Generated Money',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
              suffixText: '₴',
              suffixStyle: TextStyle(color: Colors.amber),
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Changes auto-saved',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
