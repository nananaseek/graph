import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import '../core/constants.dart';
import '../models/graph_link.dart';
import '../models/graph_node.dart';
import '../models/physics_node.dart';
import 'physics_isolate.dart';

class PhysicsEngine {
  Isolate? _isolate;
  SendPort? _sendPort;
  final StreamController<Map<String, Offset>> _updateController =
      StreamController.broadcast();

  Stream<Map<String, Offset>> get onUpdate => _updateController.stream;

  Future<void> init(Map<String, GraphNode> nodes, List<GraphLink> links) async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(physicsIsolateEntry, receivePort.sendPort);

    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is PhysicsMessage) {
        if (message.command == PhysicsCommand.updateNodes) {
          _updateController.add(message.data as Map<String, Offset>);
        }
      }
    });

    _sendPort = await completer.future;

    final config = PhysicsConfig(
      alphaStart: AppConstants.alphaStart,
      alphaMin: AppConstants.alphaMin,
      alphaDecay: AppConstants.alphaDecay,
      alphaTarget: AppConstants.alphaTarget,
      velocityDecay: AppConstants.velocityDecay,
      manyBodyStrength: AppConstants.manyBodyStrength,
      manyBodyDistanceMin: AppConstants.manyBodyDistanceMin,
      manyBodyDistanceMax: AppConstants.manyBodyDistanceMax,
      manyBodyTheta: AppConstants.manyBodyTheta,
      linkedRepulsionReduction: AppConstants.linkedRepulsionReduction,
      linkStrength: AppConstants.linkStrength,
      linkDistance: AppConstants.linkDistance,
      gravityStrength: AppConstants.gravityStrength,
      gravityDistanceScale: AppConstants.gravityDistanceScale,
    );

    final physicsNodes = nodes.values
        .map(
          (n) => PhysicsNode(
            id: n.id,
            position: n.position,
            mass: n.mass,
            radius: n.radius,
          ),
        )
        .toList();

    final physicsLinks = links
        .map((l) => PhysicsLinkData(l.sourceId, l.targetId))
        .toList();

    _sendPort!.send(
      PhysicsMessage(
        PhysicsCommand.init,
        InitialData(physicsNodes, physicsLinks, config),
      ),
    );
    _sendPort!.send(PhysicsMessage(PhysicsCommand.start));
  }

  void updateLinks(List<GraphLink> links) {
    if (_sendPort == null) return;
    final physicsLinks = links
        .map((l) => PhysicsLinkData(l.sourceId, l.targetId))
        .toList();
    _sendPort!.send(PhysicsMessage(PhysicsCommand.updateLinks, physicsLinks));
  }

  void addNode(GraphNode node) {
    if (_sendPort == null) return;
    final pNode = PhysicsNode(
      id: node.id,
      position: node.position,
      mass: node.mass,
      radius: node.radius,
    );
    _sendPort!.send(PhysicsMessage(PhysicsCommand.updateNodes, [pNode]));
  }

  void updateNodes(List<GraphNode> nodes) {
    if (_sendPort == null) return;
    final pNodes = nodes
        .map(
          (n) => PhysicsNode(
            id: n.id,
            position: n.position,
            mass: n.mass,
            radius: n.radius,
          ),
        )
        .toList();
    _sendPort!.send(PhysicsMessage(PhysicsCommand.updateNodes, pNodes));
  }

  void removeNode(String id) {
    if (_sendPort == null) return;
    _sendPort!.send(PhysicsMessage(PhysicsCommand.removeNode, id));
  }

  void updateNodePosition(String id, Offset position) {
    if (_sendPort == null) return;
    _sendPort!.send(
      PhysicsMessage(PhysicsCommand.touchNode, {
        'id': id,
        'position': position,
      }),
    );
  }

  void startDrag(String id) {
    if (_sendPort == null) return;
    _sendPort!.send(PhysicsMessage(PhysicsCommand.touchNode, {'id': id}));
  }

  void endDrag() {
    if (_sendPort == null) return;
    _sendPort!.send(
      PhysicsMessage(PhysicsCommand.touchNode, const {'id': null}),
    );
  }

  void reheat() {
    if (_sendPort == null) return;
    _sendPort!.send(PhysicsMessage(PhysicsCommand.reheat));
  }

  void dispose() {
    _sendPort?.send(PhysicsMessage(PhysicsCommand.stop));
    _isolate?.kill();
    _updateController.close();
  }
}
