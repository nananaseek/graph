import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/graph_node.dart';
import '../../models/graph_link.dart';
import '../../logic/physics_engine.dart';
import '../../core/service_locator.dart';
import '../../services/logging_service.dart';
import '../../services/graph_data_service.dart';
import '../../services/selected_node_service.dart';
import '../../services/camera_service.dart';
import '../../core/debug_constants.dart';
import '../../core/constants.dart';

import '../widgets/graph_renderer.dart';
import '../widgets/side_panel.dart';
import '../widgets/debug_panel.dart';
import '../widgets/loading_overlay.dart';

/// Tracks when a node's appearance animation starts (relative to the overall start).
class _NodeAppearSchedule {
  final String nodeId;
  final double startMs;

  _NodeAppearSchedule(this.nodeId, this.startMs);
}

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with TickerProviderStateMixin {
  late final GraphDataService _graphDataService;
  late final SelectedNodeService _selectedNodeService;
  late final CameraService _cameraService;
  late final PhysicsEngine _physicsEngine;
  final _logger = getIt<LoggingService>();

  final TransformationController _transformationController =
      TransformationController();

  StreamSubscription? _physicsSubscription;
  final ValueNotifier<int> _graphTickNotifier = ValueNotifier(0);

  final ValueNotifier<String?> _draggingNodeId = ValueNotifier(null);
  final ValueNotifier<bool> _isAnimatingCamera = ValueNotifier(false);
  Offset? _dragOffset;
  int _dragMoveCount = 0;

  Size _screenSize = Size.zero;

  // --- Node appearance animation ---
  Ticker? _appearanceTicker;
  final List<_NodeAppearSchedule> _appearSchedule = [];
  double _appearElapsedMs = 0.0;

  // --- Long press state ---
  String? _longPressNodeId;
  Timer? _longPressTimer;
  static const _longPressDuration = Duration(milliseconds: 850);

  bool _isDebugPanelOpen = false;

  // Convenience accessors
  Map<String, GraphNode> get nodes => _graphDataService.visibleNodes;
  List<GraphLink> get links => _graphDataService.visibleLinks;

  @override
  void initState() {
    super.initState();
    _graphDataService = getIt<GraphDataService>();
    _selectedNodeService = getIt<SelectedNodeService>();
    _cameraService = getIt<CameraService>();
    _physicsEngine = getIt<PhysicsEngine>();

    _cameraService.init(_transformationController, this);

    // Initialize demo data
    _graphDataService.loadDemoData();

    // Listen to expand/collapse changes in the data service
    _graphDataService.visibleTickNotifier.addListener(_onDataServiceChanged);

    Future.delayed(Duration.zero, () async {
      await _physicsEngine.init(nodes, links);

      _physicsSubscription = _physicsEngine.onUpdate.listen((positions) {
        for (var entry in positions.entries) {
          final node = nodes[entry.key];
          if (node != null) {
            node.position = entry.value;
          }
        }
        _graphTickNotifier.value++;
      });

      _physicsEngine.setGraph(nodes, links);

      _recalculateNodeSizes();
      _startNodeAppearanceAnimation();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      SidePanel.updateScreenSize(_screenSize);
      final x = _screenSize.width / 2;
      final y = _screenSize.height / 2;
      _transformationController.value = Matrix4.translationValues(x, y, 0);
    });

    _selectedNodeService.selectedNodeId.addListener(_onSelectionChanged);
  }

  /// Called when GraphDataService's visible nodes change (expand/collapse).
  void _onDataServiceChanged() {
    _physicsEngine.setGraph(nodes, links);
    _recalculateNodeSizes();

    // Animate new nodes appearing
    final newNodes = nodes.values
        .where((n) => n.appearanceScale < 1.0)
        .toList();
    if (newNodes.isNotEmpty) {
      _startNodeAppearanceAnimationForNodes(newNodes);
    }

    _graphTickNotifier.value++;
  }

  /// Build the appearance schedule and start the ticker.
  void _startNodeAppearanceAnimation() {
    final nodeIds = nodes.keys.toList()..shuffle(Random());

    _appearSchedule.clear();
    for (int i = 0; i < nodeIds.length; i++) {
      _appearSchedule.add(
        _NodeAppearSchedule(nodeIds[i], i * AppConstants.nodeAppearStaggerMs),
      );
    }

    _appearElapsedMs = 0.0;

    _appearanceTicker?.dispose();
    _appearanceTicker = createTicker(_onAppearanceTick);
    _appearanceTicker!.start();
  }

  /// Animate only specific new nodes (e.g. after expand).
  void _startNodeAppearanceAnimationForNodes(List<GraphNode> newNodes) {
    _appearSchedule.clear();
    for (int i = 0; i < newNodes.length; i++) {
      _appearSchedule.add(
        _NodeAppearSchedule(
          newNodes[i].id,
          i * AppConstants.nodeAppearStaggerMs,
        ),
      );
    }

    _appearElapsedMs = 0.0;

    _appearanceTicker?.dispose();
    _appearanceTicker = createTicker(_onAppearanceTick);
    _appearanceTicker!.start();
  }

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

      double t = localElapsed / duration;
      if (t >= 1.0) {
        node.appearanceScale = 1.0;
      } else {
        final t1 = 1.0 - t;
        node.appearanceScale = 1.0 - t1 * t1 * t1;
        allDone = false;
      }
    }

    _graphTickNotifier.value++;

    if (allDone) {
      _appearanceTicker?.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
    SidePanel.updateScreenSize(_screenSize);
  }

  @override
  void dispose() {
    _appearanceTicker?.dispose();
    _longPressTimer?.cancel();
    _physicsSubscription?.cancel();
    _physicsEngine.dispose();
    _graphTickNotifier.dispose();
    _draggingNodeId.dispose();
    _isAnimatingCamera.dispose();
    _graphDataService.visibleTickNotifier.removeListener(_onDataServiceChanged);
    _selectedNodeService.selectedNodeId.removeListener(_onSelectionChanged);
    _cameraService.dispose();
    super.dispose();
  }

  void _recalculateNodeSizes() {
    for (final node in nodes.values) {
      final descendantMoney = _graphDataService.getDescendantsMoney(node.id);
      node.updateSize(descendantMoney);
    }

    // Also update nodes in the isolate
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

  void _handleDoubleTap(Offset screenPos) {
    _cancelDrag();
    final localPos = _getLocalOffset(screenPos);
    final hitNodeId = _hitTest(localPos);

    if (hitNodeId != null) {
      // Select node + open panel
      _selectedNodeService.selectNode(hitNodeId);
      // Also set focus so visibility updates
      _graphDataService.setFocus(hitNodeId);

      _selectedNodeService.openPanel();

      if (DebugConstants.enableNodeSelectionLogging) {
        _logger.logNodeSelection(hitNodeId);
      }

      final visibleNode = nodes[hitNodeId];
      if (visibleNode != null) {
        _cameraService.animateTo(visibleNode.position, _screenSize);
      }
    }
  }

  /// Long press (2s) on a node → set focus (update visibility).
  void _startLongPress(Offset screenPos) {
    final localPos = _getLocalOffset(screenPos);
    final hitNodeId = _hitTest(localPos);

    if (hitNodeId != null) {
      _longPressNodeId = hitNodeId;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(_longPressDuration, () {
        if (_longPressNodeId == hitNodeId) {
          // Set focus on long press
          _graphDataService.setFocus(hitNodeId);
        }
        _longPressNodeId = null;
      });
    }
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressNodeId = null;
  }

  void _onSelectionChanged() {
    final selectedId = _selectedNodeService.selectedNodeId.value;
    if (selectedId != null) {
      _graphDataService.setFocus(selectedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d2029),
      body: LoadingOverlay(
        isLoadingNotifier: _graphDataService.isLoading,
        child: Stack(
          children: [
            // === Canvas ===
            Listener(
              onPointerDown: (PointerDownEvent details) {
                final localTap = _getLocalOffset(details.localPosition);
                final hitNodeId = _hitTest(localTap);
                if (hitNodeId != null) {
                  _draggingNodeId.value = hitNodeId;
                  _dragMoveCount = 0;
                  final node = nodes[hitNodeId];
                  if (node != null) {
                    _dragOffset = node.position - localTap;
                  } else {
                    _dragOffset = Offset.zero;
                  }

                  _physicsEngine.startDrag(hitNodeId, localTap + _dragOffset!);
                  if (DebugConstants.enableNodeTapLogging) {
                    _logger.logNodeDragStart(hitNodeId);
                  }
                }
              },
              onPointerMove: (PointerMoveEvent details) {
                if (_draggingNodeId.value != null) {
                  _dragMoveCount++;
                  if (_dragMoveCount % 2 != 0) return;

                  // Cancel long press if user moves finger
                  _cancelLongPress();

                  final localTap = _getLocalOffset(details.localPosition);
                  final targetPos = localTap + (_dragOffset ?? Offset.zero);

                  _physicsEngine.updateNodePosition(
                    _draggingNodeId.value!,
                    targetPos,
                  );
                }
              },
              onPointerUp: (PointerUpEvent details) {
                _cancelDrag();
              },
              child: GestureDetector(
                // Double tap → select node + open panel + camera
                onDoubleTapDown: (details) {
                  _handleDoubleTap(details.localPosition);
                },
                // Long press → expand/collapse slave nodes (2 sec)
                onLongPressStart: (details) {
                  _startLongPress(details.localPosition);
                },
                onLongPressEnd: (_) {
                  // Timer handles the 2s logic; cancel if released early
                  // (Timer continues; if user held long enough, expansion happened)
                },
                onLongPressMoveUpdate: (details) {
                  // Cancel if user moves during long press
                  _cancelLongPress();
                },
                child: ValueListenableBuilder<String?>(
                  valueListenable: _draggingNodeId,
                  builder: (context, draggingId, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isAnimatingCamera,
                      builder: (context, isAnimating, interactiveChild) {
                        return InteractiveViewer(
                          transformationController: _transformationController,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          minScale: 0.1,
                          maxScale: 5.0,
                          panEnabled: draggingId == null && !isAnimating,
                          scaleEnabled: true,
                          onInteractionStart: (details) {
                            if (details.pointerCount >= 2) {
                              _cancelDrag();
                              _cancelLongPress();
                            }
                          },
                          child: interactiveChild!,
                        );
                      },
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 5000,
                    height: 5000,
                    child: ValueListenableBuilder<Matrix4>(
                      valueListenable: _transformationController,
                      builder: (context, matrix, child) {
                        final translation = matrix.getTranslation();
                        final scale = matrix.getMaxScaleOnAxis();
                        final viewport = Rect.fromLTWH(
                          -translation.x / scale,
                          -translation.y / scale,
                          _screenSize.width / scale,
                          _screenSize.height / scale,
                        ).inflate(100);

                        return ValueListenableBuilder<String?>(
                          valueListenable: _selectedNodeService.selectedNodeId,
                          builder: (context, selectedId, _) {
                            return GraphRenderer(
                              nodes: nodes,
                              links: links,
                              tickNotifier: _graphTickNotifier,
                              selectedNodeId: selectedId,
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

            // === Menu button (Left) ===
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Color(0xFF80cde3),
                  size: 30,
                ),
                onPressed: () => _selectedNodeService.togglePanel(),
              ),
            ),

            // === Debug button (Right) ===
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.bug_report,
                  color: Colors.white54,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _isDebugPanelOpen = !_isDebugPanelOpen;
                  });
                },
              ),
            ),

            // === Side panel (Left) ===
            SidePanel(
              screenWidth: _screenSize.width > 0
                  ? _screenSize.width
                  : MediaQuery.of(context).size.width,
            ),

            // === Debug panel (Right) ===
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              right: _isDebugPanelOpen ? 0 : -300,
              child: DebugPanel(
                onClose: () {
                  setState(() {
                    _isDebugPanelOpen = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
