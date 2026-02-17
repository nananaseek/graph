import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/graph_node.dart';
import '../../models/graph_link.dart';
import '../../logic/physics_engine.dart';
import '../../core/service_locator.dart';
import '../../services/logging_service.dart';
import '../../core/debug_constants.dart';

import '../widgets/graph_renderer.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, GraphNode> nodes = {};
  final List<GraphLink> links = [];

  final TransformationController _transformationController =
      TransformationController();

  final _uuid = const Uuid();
  late final PhysicsEngine _physicsEngine;

  final _logger = getIt<LoggingService>();
  StreamSubscription? _physicsSubscription;
  final ValueNotifier<int> _graphTickNotifier = ValueNotifier(0);

  String? _draggingNodeId;
  bool _isSidebarOpen = false;
  String? _selectedNodeForLink;

  @override
  void initState() {
    super.initState();
    _physicsEngine = getIt<PhysicsEngine>();

    _addNode(const Offset(0, 0), "Main Hub");
    _addNode(const Offset(100, 100), "Note A");
    _addNode(const Offset(-100, 100), "Note B");
    _addNode(const Offset(150, 0), "Note C");

    // Create Mega Hub with 30 connections
    final hubId = _uuid.v4();
    final hubNode = GraphNode(
      id: hubId,
      position: const Offset(0, -300),
      label: "Mega Hub",
    );
    nodes[hubId] = hubNode;
    _physicsEngine.addNode(hubNode);

    for (int i = 1; i <= 30; i++) {
      final leafId = _uuid.v4();
      final leafNode = GraphNode(
        id: leafId,
        position: Offset((i * 10.0) - 150, -400),
        label: "L $i",
      );
      nodes[leafId] = leafNode;
      _physicsEngine.addNode(leafNode);
      links.add(GraphLink(hubId, leafId));
    }
    _physicsEngine.updateLinks(links);

    Future.delayed(Duration.zero, () {
      if (nodes.isEmpty) return;
      final nodeList = nodes.values.toList();
      if (nodeList.length >= 4) {
        setState(() {
          links.add(GraphLink(nodeList[0].id, nodeList[1].id));
          links.add(GraphLink(nodeList[0].id, nodeList[2].id));
          links.add(GraphLink(nodeList[0].id, nodeList[3].id));
          links.add(GraphLink(nodeList[1].id, nodeList[3].id));
        });

        _physicsEngine.init(nodes, links);

        _physicsSubscription = _physicsEngine.onUpdate.listen((positions) {
          // Update node positions
          for (var entry in positions.entries) {
            final node = nodes[entry.key];
            if (node != null) {
              node.position = entry.value;
            }
          }
          // Trigger repaint
          _graphTickNotifier.value++;
        });

        _recalculateNodeSizes();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      final x = size.width / 2;
      final y = size.height / 2;
      _transformationController.value = Matrix4.translationValues(x, y, 0);
    });
  }

  @override
  void dispose() {
    _physicsSubscription?.cancel();
    _physicsEngine.dispose();
    _graphTickNotifier.dispose();
    super.dispose();
  }

  void _addNode(Offset position, [String? text]) {
    setState(() {
      final id = _uuid.v4();
      final node = GraphNode(
        id: id,
        position: position,
        label: text ?? "Note ${nodes.length + 1}",
      );
      nodes[id] = node;
      _physicsEngine.addNode(node);
      if (DebugConstants.enableRendererLogging) {
        _logger.logNodeCreation(id);
      }
    });
  }

  void _deleteNode(String id) {
    setState(() {
      nodes.remove(id);
      links.removeWhere((l) => l.sourceId == id || l.targetId == id);
      if (_draggingNodeId == id) _draggingNodeId = null;
      if (_selectedNodeForLink == id) _selectedNodeForLink = null;

      _physicsEngine.removeNode(id);
      if (DebugConstants.enableRendererLogging) {
        _logger.logNodeDeletion(id);
      }
      _recalculateNodeSizes();
    });
  }

  void _recalculateNodeSizes() {
    // 1. Reset degrees
    final degrees = <String, int>{};
    for (final node in nodes.values) {
      degrees[node.id] = 0;
    }

    // 2. Count links
    for (final link in links) {
      degrees[link.sourceId] = (degrees[link.sourceId] ?? 0) + 1;
      degrees[link.targetId] = (degrees[link.targetId] ?? 0) + 1;
    }

    // 3. Update nodes
    for (final node in nodes.values) {
      final degree = degrees[node.id] ?? 0;
      node.updateSize(degree);
    }

    // 4. Notify physics engine about mass/radius changes
    _physicsEngine.updateNodes(nodes.values.toList());
  }

  Offset _getLocalOffset(Offset screenPosition) {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    return (screenPosition - Offset(translation.x, translation.y)) / scale;
  }

  void _cancelDrag() {
    if (_draggingNodeId != null) {
      _physicsEngine.endDrag();
      if (DebugConstants.enableNodeTapLogging) {
        _logger.logNodeDragEnd(_draggingNodeId!);
      }
      setState(() => _draggingNodeId = null);
    }
  }

  String? _hitTest(Offset localPosition) {
    for (final node in nodes.values) {
      if ((node.position - localPosition).distance <= node.radius + 15.0) {
        return node.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Stack(
        children: [
          Listener(
            onPointerDown: (PointerDownEvent details) {
              final localTap = _getLocalOffset(details.localPosition);
              final hitNodeId = _hitTest(localTap);
              if (hitNodeId != null) {
                setState(() => _draggingNodeId = hitNodeId);
                _physicsEngine.startDrag(hitNodeId);
                if (DebugConstants.enableNodeTapLogging) {
                  _logger.logNodeDragStart(hitNodeId);
                }
              }
            },
            onPointerMove: (PointerMoveEvent details) {
              if (_draggingNodeId != null) {
                final localTap = _getLocalOffset(details.localPosition);

                final node = nodes[_draggingNodeId];
                if (node != null) {
                  node.position = localTap;
                  _physicsEngine.updateNodePosition(_draggingNodeId!, localTap);
                }
              }
            },
            onPointerUp: (PointerUpEvent details) {
              _cancelDrag();
            },
            child: GestureDetector(
              onDoubleTapDown: (details) {
                final offset = _getLocalOffset(details.localPosition);
                final hitNodeId = _hitTest(offset);

                if (hitNodeId != null) {
                  if (_selectedNodeForLink != null &&
                      _selectedNodeForLink != hitNodeId) {
                    setState(() {
                      final existingLinkIndex = links.indexWhere(
                        (l) =>
                            (l.sourceId == _selectedNodeForLink &&
                                l.targetId == hitNodeId) ||
                            (l.sourceId == hitNodeId &&
                                l.targetId == _selectedNodeForLink),
                      );

                      if (existingLinkIndex != -1) {
                        links.removeAt(existingLinkIndex);
                      } else {
                        links.add(GraphLink(_selectedNodeForLink!, hitNodeId));
                      }

                      _physicsEngine.updateLinks(links);
                      _physicsEngine.updateLinks(links);
                      if (DebugConstants.enableRendererLogging) {
                        _logger.logLinkCreation(
                          _selectedNodeForLink!,
                          hitNodeId,
                        );
                      }

                      _selectedNodeForLink = null;
                      _recalculateNodeSizes();
                    });
                  } else {
                    if (_selectedNodeForLink == hitNodeId) {
                      if (DebugConstants.enableNodeSelectionLogging) {
                        _logger.logNodeDeselection(_selectedNodeForLink!);
                      }
                      setState(() => _selectedNodeForLink = null);
                    } else {
                      // Select node for linking (or re-select)
                      setState(() => _selectedNodeForLink = hitNodeId);
                      if (DebugConstants.enableNodeSelectionLogging) {
                        _logger.logNodeSelection(hitNodeId);
                      }
                    }
                  }
                } else {
                  _addNode(offset);
                }
              },
              onTapUp: (details) {
                if (_selectedNodeForLink != null) {
                  final localTap = _getLocalOffset(details.localPosition);
                  final hitNodeId = _hitTest(localTap);

                  if (hitNodeId != null && hitNodeId != _selectedNodeForLink) {
                    setState(() {
                      final existingLinkIndex = links.indexWhere(
                        (l) =>
                            (l.sourceId == _selectedNodeForLink &&
                                l.targetId == hitNodeId) ||
                            (l.sourceId == hitNodeId &&
                                l.targetId == _selectedNodeForLink),
                      );

                      if (existingLinkIndex != -1) {
                        links.removeAt(existingLinkIndex);
                      } else {
                        links.add(GraphLink(_selectedNodeForLink!, hitNodeId));
                        if (DebugConstants.enableRendererLogging) {
                          _logger.logLinkCreation(
                            _selectedNodeForLink!,
                            hitNodeId,
                          );
                        }
                      }

                      _physicsEngine.updateLinks(links);

                      _selectedNodeForLink = null;
                      _recalculateNodeSizes();
                    });
                  } else if (hitNodeId == null) {
                    if (DebugConstants.enableNodeSelectionLogging) {
                      _logger.logNodeDeselection(_selectedNodeForLink!);
                    }
                    setState(() => _selectedNodeForLink = null);
                  }
                }
              },
              child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.1,
                maxScale: 5.0,
                panEnabled: _draggingNodeId == null,
                scaleEnabled: true,
                onInteractionStart: (details) {
                  // If user starts pinching (2+ fingers), cancel any node drag
                  if (details.pointerCount >= 2) {
                    _cancelDrag();
                  }
                },
                child: SizedBox(
                  width: 20000,
                  height: 20000,
                  child: SizedBox(
                    width: 20000,
                    height: 20000,
                    child: Builder(
                      builder: (context) {
                        return AnimatedBuilder(
                          animation: _transformationController,
                          builder: (context, _) {
                            final matrix = _transformationController.value;
                            final translation = matrix.getTranslation();
                            final scale = matrix.getMaxScaleOnAxis();
                            final viewport = Rect.fromLTWH(
                              -translation.x / scale,
                              -translation.y / scale,
                              MediaQuery.of(context).size.width / scale,
                              MediaQuery.of(context).size.height / scale,
                            ).inflate(100);

                            if (DebugConstants.enableRendererLogging) {
                              // Calculate rendered nodes count
                              int renderedCount = 0;
                              for (final node in nodes.values) {
                                // Simple AABB check matching GraphPainter
                                final nodeRect = Rect.fromCircle(
                                  center: node.position,
                                  radius: node.radius + 20,
                                );
                                if (viewport.overlaps(nodeRect)) {
                                  renderedCount++;
                                }
                              }
                              // We use print here as the LoggerService might not have a specific method for this
                              // or we can add one. For now using debugPrint or similar.
                              debugPrint(
                                'Rendered nodes: $renderedCount / ${nodes.length}',
                              );
                            }

                            return GraphRenderer(
                              nodes: nodes,
                              links: links,
                              tickNotifier: _graphTickNotifier,
                              selectedNodeId: _selectedNodeForLink,
                              viewport: viewport,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            left: _isSidebarOpen ? 0 : -300,
            width: 300,
            child: Material(
              color: const Color(0xFF252525).withOpacity(0.95),
              elevation: 10,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Твої Графи",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () =>
                                setState(() => _isSidebarOpen = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes.values.elementAt(index);
                          return ListTile(
                            leading: const Icon(
                              Icons.circle,
                              color: Color(0xFF9C27B0),
                              size: 16,
                            ),
                            title: Text(
                              node.label,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteNode(node.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
