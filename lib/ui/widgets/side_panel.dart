import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../services/graph_data_service.dart';
import '../../services/selected_node_service.dart';
import '../../services/camera_service.dart';
import '../../services/debug_service.dart';
import '../../models/graph_node.dart';

enum NodeSortOption { defaultSort, nameAsc, profitDesc }

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

class _PanelContent extends StatefulWidget {
  final List<String> stack;

  const _PanelContent({required this.stack});

  @override
  State<_PanelContent> createState() => _PanelContentState();
}

class _PanelContentState extends State<_PanelContent> {
  String _searchQuery = '';
  NodeSortOption _sortOption = NodeSortOption.defaultSort;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset search when navigating between nodes
    if (oldWidget.stack.length != widget.stack.length ||
        (oldWidget.stack.isNotEmpty &&
            widget.stack.isNotEmpty &&
            oldWidget.stack.last != widget.stack.last)) {
      _searchQuery = '';
      _searchController.clear();
      _sortOption = NodeSortOption.defaultSort;
    }
  }

  List<GraphNode> _filterAndSortNodes(
    List<GraphNode> nodes,
    GraphDataService gds,
  ) {
    var result = nodes;

    // 1. Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((node) => node.name.toLowerCase().contains(query))
          .toList();
    } else {
      result = result.toList(); // Copy to avoid mutating original list
    }

    // 2. Sort
    switch (_sortOption) {
      case NodeSortOption.nameAsc:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case NodeSortOption.profitDesc:
        result.sort((a, b) {
          final moneyA = a.selfGeneratedMoney + gds.getDescendantsMoney(a.id);
          final moneyB = b.selfGeneratedMoney + gds.getDescendantsMoney(b.id);
          return moneyB.compareTo(moneyA);
        });
        break;
      case NodeSortOption.defaultSort:
        // Do nothing, keep original order
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final graphDataService = getIt<GraphDataService>();
    final selectedNodeService = getIt<SelectedNodeService>();
    final debugService = getIt<DebugService>();

    return ValueListenableBuilder<bool>(
      valueListenable: debugService.isEditMode,
      builder: (context, isEditMode, _) {
        return ValueListenableBuilder<int>(
          valueListenable: graphDataService.visibleTickNotifier,
          builder: (context, _, _) {
            // Root level — show master nodes list
            if (widget.stack.isEmpty) {
              return _buildRootView(
                graphDataService,
                selectedNodeService,
                isEditMode,
              );
            }

            final currentNodeId = widget.stack.last;
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
      },
    );
  }

  Widget _buildSearchAndFilterBlock() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Пошук за іменем...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withAlpha(15), // M3 search bar style
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<NodeSortOption>(
            initialValue: _sortOption,
            tooltip: 'Сортування',
            icon: Icon(
              Icons.filter_list,
              color: _sortOption != NodeSortOption.defaultSort
                  ? const Color(0xFF80cde3)
                  : Colors.white54,
            ),
            color: const Color(0xFF252525),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (NodeSortOption result) {
              setState(() {
                _sortOption = result;
              });
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<NodeSortOption>>[
                  const PopupMenuItem<NodeSortOption>(
                    value: NodeSortOption.defaultSort,
                    child: Text(
                      'За замовчуванням',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem<NodeSortOption>(
                    value: NodeSortOption.nameAsc,
                    child: Text(
                      'За іменем (А-Я)',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem<NodeSortOption>(
                    value: NodeSortOption.profitDesc,
                    child: Text(
                      'За прибутком (спад.)',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildRootView(
    GraphDataService gds,
    SelectedNodeService sns,
    bool isEditMode,
  ) {
    final rawMasters = gds.masterNodes;
    final processedMasters = _filterAndSortNodes(rawMasters, gds);

    final totalNodes = gds.allNodes.length;
    final totalMoney = gds.allNodes.values.fold(
      0.0,
      (sum, node) => sum + node.selfGeneratedMoney,
    );

    return Column(
      children: [
        _buildHeader(
          title: 'Твої реферали',
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

        _buildSearchAndFilterBlock(),

        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: processedMasters.isEmpty
              ? const Center(
                  child: Text(
                    'Нічого не знайдено',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  itemCount: processedMasters.length,
                  itemBuilder: (context, index) {
                    final node = processedMasters[index];
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
    BuildContext context,
    GraphNode node,
    GraphDataService gds,
    SelectedNodeService sns,
    bool isEditMode,
  ) {
    final rawChildren = gds.getChildren(node.id);
    final processedChildren = _filterAndSortNodes(rawChildren, gds);

    return Column(
      children: [
        _buildHeader(
          title: node.name,
          onClose: () => sns.closePanel(),
          onBack: () => _navigateBackAndFocus(sns),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (isEditMode)
                      _NodeEditor(node: node, onUpdate: gds.updateNode)
                    else
                      _InfoCard(node: node),

                    const SizedBox(height: 20),

                    if (isEditMode) ...[
                      _buildActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Створити ноду реферала',
                        color: Colors.amber,
                        onTap: () => gds.createSlaveNode(node.id),
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'Видалити реферала',
                        color: Colors.redAccent,
                        onTap: () {
                          _showDeleteConfirm(context, node, gds, sns);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

              if (rawChildren.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 8.0,
                    top: 4.0,
                  ),
                  child: Text(
                    'Підпорядковані ноди',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildSearchAndFilterBlock(),
                const Divider(color: Colors.white12, height: 1),
                if (processedChildren.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'Нічого не знайдено',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...processedChildren.map(
                    (child) => _NodeListTile(
                      node: child,
                      onTap: () => _onNodeTap(child, sns),
                    ),
                  ),
              ],
              if (rawChildren.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      'Немає підпорядкованих рефералів',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
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

  void _navigateBackAndFocus(SelectedNodeService sns) {
    sns.navigateBack();
    final parentId = sns.selectedNodeId.value;
    if (parentId != null) {
      final cameraService = getIt<CameraService>();
      final graphDataService = getIt<GraphDataService>();
      final visibleNode = graphDataService.visibleNodes[parentId];
      if (visibleNode != null) {
        final screenSize = SidePanel._cachedScreenSize;
        if (screenSize != null) {
          cameraService.animateTo(visibleNode.position, screenSize);
        }
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
      borderRadius: BorderRadius.circular(16), // Material 3
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20), // M3 softer color
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40)),
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
      _navigateBackAndFocus(sns);
      gds.deleteNode(node.id);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ), // M3 look
        title: const Text(
          'Видалити реферала?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Цей реферал має ${node.childrenIds.length} підлеглих. Видалення цього реферала призведе до видалення всіх його підлеглих.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Скасувати'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withAlpha(40),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Видалити'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateBackAndFocus(sns);
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
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF80cde3).withAlpha(15), // M3 softer background
        borderRadius: BorderRadius.circular(16), // M3 higher border radius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            Icons.account_tree,
            'Всього рефералів',
            '$totalNodes ${totalNodes % 10 == 1 && totalNodes % 100 != 11
                ? 'реферал'
                : (totalNodes % 10 >= 2 && totalNodes % 10 <= 4 && (totalNodes % 100 < 10 || totalNodes % 100 >= 20))
                ? 'реферала'
                : 'рефералів'}',
          ),
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
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        color: const Color(0xFF80cde3).withAlpha(15), // M3 softer
        borderRadius: BorderRadius.circular(16), // M3 smoother radius
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
            'Від мережі',
            '${descendantsMoney.toStringAsFixed(0)} ₴',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.account_balance_wallet,
            'Загалом гілка',
            '${totalMoney.toStringAsFixed(0)} ₴',
          ),
          const Divider(color: Colors.white12, height: 24),
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
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
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
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF80cde3).withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: Icon(
          node.childrenIds.isNotEmpty ? Icons.hub : Icons.person,
          color: const Color(0xFF80cde3),
          size: 18,
        ),
      ),
      title: Text(
        node.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${totalMoney.toStringAsFixed(0)} ₴  •  ${node.childrenIds.length} ${node.childrenIds.length % 10 == 1 && node.childrenIds.length % 100 != 11
            ? 'реферал'
            : (node.childrenIds.length % 10 >= 2 && node.childrenIds.length % 10 <= 4 && (node.childrenIds.length % 100 < 10 || node.childrenIds.length % 100 >= 20))
            ? 'реферала'
            : 'рефералів'}',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: node.childrenIds.isNotEmpty
          ? const Icon(Icons.chevron_right, color: Colors.white38, size: 20)
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(16), // Material 3
        border: Border.all(color: Colors.amber.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Редагувати реферала',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ім\'я',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.amber, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _moneyCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Власні генерування',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.amber, width: 1.5),
              ),
              suffixText: '₴',
              suffixStyle: const TextStyle(color: Colors.amber),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Зміни автоматично зберігаються',
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
