import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import '../../models/graph_node.dart';
import '../../models/graph_link.dart';
import '../../logic/physics_engine.dart';
import '../../core/service_locator.dart';
import '../../services/logging_service.dart';
import '../../core/debug_constants.dart';
import '../../core/constants.dart';

import '../widgets/graph_renderer.dart';

/// Tracks when a node's appearance animation starts (relative to the overall start).
class _NodeAppearSchedule {
  final String nodeId;
  final double startMs; // Delay before this node starts appearing

  _NodeAppearSchedule(this.nodeId, this.startMs);
}

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

  final ValueNotifier<String?> _draggingNodeId = ValueNotifier(null);
  bool _isSidebarOpen = false;
  String? _selectedNodeForLink;
  int _dragMoveCount = 0;

  Size _screenSize = Size.zero;

  // --- Node appearance animation ---
  Ticker? _appearanceTicker;
  final List<_NodeAppearSchedule> _appearSchedule = [];
  double _appearElapsedMs = 0.0;
  bool _appearAnimationActive = false;

  @override
  void initState() {
    super.initState();
    _physicsEngine = getIt<PhysicsEngine>();

    // Mark batch animation as active so _addNode doesn't trigger individual timers
    _appearAnimationActive = true;

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

        // Start staggered appearance animation
        _startNodeAppearanceAnimation();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      final x = _screenSize.width / 2;
      final y = _screenSize.height / 2;
      _transformationController.value = Matrix4.translationValues(x, y, 0);
    });
  }

  /// Build the appearance schedule and start the ticker.
  void _startNodeAppearanceAnimation() {
    // Shuffle node IDs for random order
    final nodeIds = nodes.keys.toList()..shuffle(Random());

    _appearSchedule.clear();
    for (int i = 0; i < nodeIds.length; i++) {
      _appearSchedule.add(
        _NodeAppearSchedule(nodeIds[i], i * AppConstants.nodeAppearStaggerMs),
      );
    }

    _appearElapsedMs = 0.0;
    _appearAnimationActive = true;

    _appearanceTicker?.dispose();
    _appearanceTicker = createTicker(_onAppearanceTick);
    _appearanceTicker!.start();
  }

  /// Called every frame while the appearance animation runs.
  void _onAppearanceTick(Duration elapsed) {
    _appearElapsedMs = elapsed.inMicroseconds / 1000.0;

    bool allDone = true;
    final duration = AppConstants.nodeAppearDurationMs;

    for (final schedule in _appearSchedule) {
      final node = nodes[schedule.nodeId];
      if (node == null) continue;

      final localElapsed = _appearElapsedMs - schedule.startMs;

      if (localElapsed <= 0.0) {
        allDone = false;
        continue;
      }

      if (node.appearanceScale >= 1.0) {
        continue;
      }

      // Linear progress 0→1
      double t = localElapsed / duration;
      if (t >= 1.0) {
        node.appearanceScale = 1.0;
      } else {
        // easeOutCubic — cheap: no trig, just one multiply
        final t1 = 1.0 - t;
        node.appearanceScale = 1.0 - t1 * t1 * t1;
        allDone = false;
      }
    }

    // No need to trigger _graphTickNotifier here —
    // the physics ticker already repaints every frame.
    // This ticker only updates the scale values.

    if (allDone) {
      // Final repaint to ensure all nodes show text (scale == 1.0)
      _graphTickNotifier.value++;
      _appearanceTicker?.stop();
      _appearAnimationActive = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    _appearanceTicker?.dispose();
    _physicsSubscription?.cancel();
    _physicsEngine.dispose();
    _graphTickNotifier.dispose();
    _draggingNodeId.dispose();
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

      // If the initial animation is done, animate this single node immediately
      if (!_appearAnimationActive) {
        _animateSingleNodeAppearance(node);
      }
    });
  }

  /// Animate a single newly-added node after initial batch animation is complete.
  void _animateSingleNodeAppearance(GraphNode node) {
    final duration = AppConstants.nodeAppearDurationMs;
    final startTime = DateTime.now();

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final elapsed =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;
      final t = (elapsed / duration).clamp(0.0, 1.0);
      node.appearanceScale = Curves.elasticOut.transform(t);
      _graphTickNotifier.value++;

      if (t >= 1.0) {
        node.appearanceScale = 1.0;
        timer.cancel();
      }
    });
  }

  void _deleteNode(String id) {
    setState(() {
      nodes.remove(id);
      links.removeWhere((l) => l.sourceId == id || l.targetId == id);
      if (_draggingNodeId.value == id) _draggingNodeId.value = null;
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
    if (_draggingNodeId.value != null) {
      _physicsEngine.endDrag();
      if (DebugConstants.enableNodeTapLogging) {
        _logger.logNodeDragEnd(_draggingNodeId.value!);
      }
      _draggingNodeId.value = null;
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
                _draggingNodeId.value = hitNodeId;
                _dragMoveCount = 0;
                _physicsEngine.startDrag(hitNodeId);
                if (DebugConstants.enableNodeTapLogging) {
                  _logger.logNodeDragStart(hitNodeId);
                }
              }
            },
            onPointerMove: (PointerMoveEvent details) {
              if (_draggingNodeId.value != null) {
                // Throttle: skip every other pointer event to halve raster load
                _dragMoveCount++;
                if (_dragMoveCount % 2 != 0) return;

                final localTap = _getLocalOffset(details.localPosition);

                final node = nodes[_draggingNodeId.value];
                if (node != null) {
                  node.position = localTap;
                  _physicsEngine.updateNodePosition(
                    _draggingNodeId.value!,
                    localTap,
                  );
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
              child: ValueListenableBuilder<String?>(
                valueListenable: _draggingNodeId,
                builder: (context, draggingId, interactiveChild) {
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.1,
                    maxScale: 5.0,
                    panEnabled: draggingId == null,
                    scaleEnabled: true,
                    onInteractionStart: (details) {
                      // If user starts pinching (2+ fingers), cancel any node drag
                      if (details.pointerCount >= 2) {
                        _cancelDrag();
                      }
                    },
                    child: interactiveChild!,
                  );
                },
                child: SizedBox(
                  width: 5000,
                  height: 5000,
                  child: ValueListenableBuilder<Matrix4>(
                    valueListenable: _transformationController,
                    builder: (context, matrix, child) {
                      // Calculate viewport here
                      final translation = matrix.getTranslation();
                      final scale = matrix.getMaxScaleOnAxis();
                      final viewport = Rect.fromLTWH(
                        -translation.x / scale,
                        -translation.y / scale,
                        _screenSize.width / scale,
                        _screenSize.height / scale,
                      ).inflate(100);

                      return GraphRenderer(
                        nodes: nodes,
                        links: links,
                        tickNotifier: _graphTickNotifier,
                        selectedNodeId: _selectedNodeForLink,
                        viewport: viewport,
                      );
                    },
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
              color: const Color.fromRGBO(37, 37, 37, 0.95),
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
