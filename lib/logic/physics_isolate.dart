import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:math';

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
  final double gravityStrength;
  final double gravityDistanceScale;

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
    this.gravityDistanceScale = 500.0,
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

  // Frame counter for message throttling
  int _frameCount = 0;

  void _recomputeDegrees() {
    _nodeDegrees = {};
    for (final link in links) {
      _nodeDegrees[link.sourceId] = (_nodeDegrees[link.sourceId] ?? 0) + 1;
      _nodeDegrees[link.targetId] = (_nodeDegrees[link.targetId] ?? 0) + 1;
    }
  }

  // Stop timer — called when simulation converges
  void _stopTimer() {
    loopTimer?.cancel();
    loopTimer = null;
  }

  // step() is declared next (see below), then _startTimer references it

  void step() {
    if (nodes.isEmpty) return;

    alpha += (config.alphaTarget - alpha) * config.alphaDecay;

    if (alpha < config.alphaMin) {
      // Simulation converged — stop the timer to save CPU
      _stopTimer();
      return;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var node in nodes.values) {
      final dx = node.position.dx;
      final dy = node.position.dy;
      if (dx < minX) minX = dx;
      if (dy < minY) minY = dy;
      if (dx > maxX) maxX = dx;
      if (dy > maxY) maxY = dy;
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

    // Merged loop: linked repulsion correction + link spring forces
    // Computes delta/distance once per link pair instead of twice
    for (final link in links) {
      final n1 = nodes[link.sourceId];
      final n2 = nodes[link.targetId];
      if (n1 == null || n2 == null) continue;
      if (n1.id == n2.id) continue;

      Offset delta = n2.position - n1.position;
      double distance = delta.distance;

      if (distance == 0) {
        distance = 0.1;
        delta = const Offset(0.1, 0);
      }

      // --- Linked repulsion correction ---
      if (distance <= config.manyBodyDistanceMax &&
          config.linkedRepulsionReduction != 0) {
        final clampedDist = distance < config.manyBodyDistanceMin
            ? config.manyBodyDistanceMin
            : distance;
        final repulsionApprox =
            config.manyBodyStrength * alpha * n2.mass / clampedDist;
        // Use already-computed distance for normalization
        final correction =
            (delta / distance) *
            repulsionApprox *
            config.linkedRepulsionReduction;

        if (n1.id != draggingNodeId) n1.velocity -= correction;
        if (n2.id != draggingNodeId) n2.velocity += correction;
      }

      // --- Link spring force ---
      final displacement =
          (distance - config.linkDistance) /
          distance *
          alpha *
          config.linkStrength;

      final sourceDegree = _nodeDegrees[n1.id] ?? 1;
      final targetDegree = _nodeDegrees[n2.id] ?? 1;
      final bias = sourceDegree / (sourceDegree + targetDegree);

      if (n2.id != draggingNodeId) {
        n2.velocity -= delta * displacement * bias;
      }
      if (n1.id != draggingNodeId) {
        n1.velocity += delta * displacement * (1 - bias);
      }
    }

    for (final node in nodes.values) {
      if (node.id == draggingNodeId) continue;

      final dist = node.position.distance;
      // Soft non-linear scaling: sqrt(dist / scale)
      // Resulting force: F ∝ dist * sqrt(dist) = dist^1.5
      final scaling = sqrt(dist / config.gravityDistanceScale);

      final gravity =
          node.position *
          config.gravityStrength *
          alpha *
          sqrt(node.mass) *
          scaling;
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

    // Throttle messages: send every other frame to reduce main isolate load
    _frameCount++;
    if (_frameCount % 2 == 0) {
      final updates = {for (var n in nodes.values) n.id: n.position};
      sendPort.send(PhysicsMessage(PhysicsCommand.updateNodes, updates));
    }
  }

  // Start or restart the simulation timer
  void _startTimer() {
    if (loopTimer != null && loopTimer!.isActive) return;
    loopTimer?.cancel();
    loopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => step());
  }

  void _reheat() {
    alpha = config.alphaStart;
    _startTimer();
  }

  // Message Loop
  receivePort.listen((message) {
    if (message is PhysicsMessage) {
      switch (message.command) {
        case PhysicsCommand.start:
          _startTimer();
          break;

        case PhysicsCommand.stop:
          _stopTimer();
          break;

        case PhysicsCommand.init:
          if (message.data is InitialData) {
            final data = message.data as InitialData;
            nodes.clear();
            links.clear();
            for (var n in data.nodes) {
              nodes[n.id] = n;
            }
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
