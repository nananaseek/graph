import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import '../models/physics_node.dart';
import 'quadtree.dart';

// Commands
enum PhysicsCommand {
  init,
  updateNodes,
  updateLinks,
  removeNode,
  updateViewport,
  start,
  stop,
  touchNode,
  reheat,
}

class PhysicsMessage {
  final PhysicsCommand command;
  final dynamic data;

  PhysicsMessage(this.command, [this.data]);
}

class PhysicsLinkData {
  final String sourceId;
  final String targetId;

  PhysicsLinkData(this.sourceId, this.targetId);
}

class PhysicsConfig {
  final double alphaStart;
  final double alphaMin;
  final double alphaDecay;
  final double alphaTarget;
  final double velocityDecay;
  final double manyBodyStrength;
  final double manyBodyDistanceMin;
  final double manyBodyDistanceMax;
  final double manyBodyTheta;
  final double linkedRepulsionReduction;
  final double linkStrength;
  final double linkDistance;
  final double gravityStrength; // Gravity

  const PhysicsConfig({
    this.alphaStart = 1.0,
    this.alphaMin = 0.001,
    this.alphaDecay = 0.0228,
    this.alphaTarget = 0.0,
    this.velocityDecay = 0.4,
    this.manyBodyStrength = -120.0,
    this.manyBodyDistanceMin = 1.0,
    this.manyBodyDistanceMax = 1000.0,
    this.manyBodyTheta = 0.9,
    this.linkedRepulsionReduction = 0.7,
    this.linkStrength = 0.8,
    this.linkDistance = 70.0,
    this.gravityStrength = 0.1,
  });
}

void physicsIsolateEntry(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final Map<String, PhysicsNode> nodes = {};
  final List<PhysicsLinkData> links = [];
  Timer? loopTimer;

  // Config (defaults, overridden by init)
  PhysicsConfig config = const PhysicsConfig();

  // D3-force alpha state
  double alpha = 1.0;

  // Precomputed link degree counts for D3-style bias
  Map<String, int> _nodeDegrees = {};

  // State
  String? draggingNodeId;

  void _recomputeDegrees() {
    _nodeDegrees = {};
    for (final link in links) {
      _nodeDegrees[link.sourceId] = (_nodeDegrees[link.sourceId] ?? 0) + 1;
      _nodeDegrees[link.targetId] = (_nodeDegrees[link.targetId] ?? 0) + 1;
    }
  }

  void _reheat() {
    alpha = config.alphaStart;
  }

  void step() {
    if (nodes.isEmpty) return;

    alpha += (config.alphaTarget - alpha) * config.alphaDecay;

    if (alpha < config.alphaMin) {
      return;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var node in nodes.values) {
      if (node.position.dx < minX) minX = node.position.dx;
      if (node.position.dy < minY) minY = node.position.dy;
      if (node.position.dx > maxX) maxX = node.position.dx;
      if (node.position.dy > maxY) maxY = node.position.dy;
    }

    final boundary = Rect.fromLTRB(
      minX - 500,
      minY - 500,
      maxX + 500,
      maxY + 500,
    );
    final quadtree = Quadtree(boundary, theta: config.manyBodyTheta);

    for (var node in nodes.values) {
      quadtree.insert(node);
    }

    for (var node in nodes.values) {
      if (node.id == draggingNodeId) continue;

      final force = quadtree.calculateForce(
        node,
        config.manyBodyStrength,
        alpha,
        distanceMin: config.manyBodyDistanceMin,
        distanceMax: config.manyBodyDistanceMax,
      );
      node.velocity += force;
    }

    for (final link in links) {
      final n1 = nodes[link.sourceId];
      final n2 = nodes[link.targetId];
      if (n1 == null || n2 == null) continue;

      Offset delta = n2.position - n1.position;
      double distance = delta.distance;
      if (distance < config.manyBodyDistanceMin) {
        distance = config.manyBodyDistanceMin;
      }
      if (distance > config.manyBodyDistanceMax) continue;

      // Approximate the repulsion that was applied between this pair
      final repulsionApprox =
          config.manyBodyStrength * alpha * n2.mass / distance;
      final correction =
          (delta / delta.distance) *
          repulsionApprox *
          config.linkedRepulsionReduction;

      if (n1.id != draggingNodeId) n1.velocity -= correction;
      if (n2.id != draggingNodeId) n2.velocity += correction;
    }

    for (final link in links) {
      final source = nodes[link.sourceId];
      final target = nodes[link.targetId];

      if (source == null || target == null) continue;
      if (source.id == target.id) continue;

      Offset delta = target.position - source.position;
      double distance = delta.distance;
      if (distance == 0) {
        distance = 0.1;
        delta = const Offset(0.1, 0);
      }

      final displacement =
          (distance - config.linkDistance) /
          distance *
          alpha *
          config.linkStrength;

      final sourceDegree = _nodeDegrees[source.id] ?? 1;
      final targetDegree = _nodeDegrees[target.id] ?? 1;
      final bias = sourceDegree / (sourceDegree + targetDegree);

      if (target.id != draggingNodeId) {
        target.velocity -= delta * displacement * bias;
      }
      if (source.id != draggingNodeId) {
        source.velocity += delta * displacement * (1 - bias);
      }
    }

    for (final node in nodes.values) {
      if (node.id == draggingNodeId) continue;

      final gravity = node.position * config.gravityStrength * alpha;
      node.velocity -= gravity;
    }

    for (final node in nodes.values) {
      if (node.id == draggingNodeId) {
        node.velocity = Offset.zero;
        continue;
      }

      node.position += node.velocity;
      node.velocity *= (1.0 - config.velocityDecay);
    }

    final updates = {for (var n in nodes.values) n.id: n.position};
    sendPort.send(PhysicsMessage(PhysicsCommand.updateNodes, updates));
  }

  // Message Loop
  receivePort.listen((message) {
    if (message is PhysicsMessage) {
      switch (message.command) {
        case PhysicsCommand.start:
          loopTimer?.cancel();
          loopTimer = Timer.periodic(
            const Duration(milliseconds: 16),
            (_) => step(),
          );
          break;

        case PhysicsCommand.stop:
          loopTimer?.cancel();
          break;

        case PhysicsCommand.init:
          if (message.data is InitialData) {
            final data = message.data as InitialData;
            nodes.clear();
            links.clear();
            for (var n in data.nodes) nodes[n.id] = n;
            links.addAll(data.links);
            if (data.config != null) {
              config = data.config!;
            }
            _recomputeDegrees();
            _reheat();
          }
          break;

        case PhysicsCommand.updateNodes:
          if (message.data is List<PhysicsNode>) {
            for (var n in (message.data as List<PhysicsNode>)) {
              nodes[n.id] = n;
            }
            _reheat();
          }
          break;

        case PhysicsCommand.removeNode:
          if (message.data is String) {
            final id = message.data as String;
            nodes.remove(id);
            links.removeWhere((l) => l.sourceId == id || l.targetId == id);
            _recomputeDegrees();
            _reheat();
          }
          break;

        case PhysicsCommand.updateLinks:
          if (message.data is List<PhysicsLinkData>) {
            links.clear();
            links.addAll(message.data as List<PhysicsLinkData>);
            _recomputeDegrees();
            _reheat();
          }
          break;

        case PhysicsCommand.touchNode:
          final map = message.data as Map;
          final id = map['id'] as String?;
          if (id != null) {
            draggingNodeId = id;
            if (map.containsKey('position')) {
              nodes[id]?.position = map['position'] as Offset;
              nodes[id]?.velocity = Offset.zero;
            }

            _reheat();
          } else {
            if (map.containsKey('velocity') && draggingNodeId != null) {
              nodes[draggingNodeId!]?.velocity = map['velocity'] as Offset;
            }
            draggingNodeId = null;
          }
          break;

        case PhysicsCommand.reheat:
          _reheat();
          break;

        default:
          break;
      }
    }
  });
}

class InitialData {
  final List<PhysicsNode> nodes;
  final List<PhysicsLinkData> links;
  final PhysicsConfig? config;
  InitialData(this.nodes, this.links, [this.config]);
}
