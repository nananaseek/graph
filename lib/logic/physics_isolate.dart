import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../models/physics_node.dart';
import 'quadtree.dart';

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
  Map<String, int> nodeDegrees = {};

  // State
  String? draggingNodeId;

  // Frame counter for message throttling
  int frameCount = 0;

  // Reusable force accumulator — avoids Offset allocations
  final ForceAccum forceAccum = ForceAccum();
  final QuadtreeNodePool quadtreePool = QuadtreeNodePool();

  void recomputeDegrees() {
    nodeDegrees = {};
    for (final link in links) {
      nodeDegrees[link.sourceId] = (nodeDegrees[link.sourceId] ?? 0) + 1;
      nodeDegrees[link.targetId] = (nodeDegrees[link.targetId] ?? 0) + 1;
    }
  }

  // Stop timer — called when simulation converges
  void stopTimer() {
    loopTimer?.cancel();
    loopTimer = null;
  }

  void step() {
    if (nodes.isEmpty) return;

    alpha += (config.alphaTarget - alpha) * config.alphaDecay;

    if (alpha < config.alphaMin) {
      // Simulation converged — stop the timer to save CPU
      stopTimer();
      return;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var node in nodes.values) {
      if (node.px < minX) minX = node.px;
      if (node.py < minY) minY = node.py;
      if (node.px > maxX) maxX = node.px;
      if (node.py > maxY) maxY = node.py;
    }

    final bLeft = minX - 500;
    final bTop = minY - 500;
    final bWidth = (maxX + 500) - bLeft;
    final bHeight = (maxY + 500) - bTop;

    quadtreePool.releaseAll();
    final quadtree = Quadtree(
      bLeft,
      bTop,
      bWidth,
      bHeight,
      theta: config.manyBodyTheta,
      pool: quadtreePool,
    );

    for (var node in nodes.values) {
      quadtree.insert(node);
    }

    // Many-body forces via Barnes-Hut
    for (var node in nodes.values) {
      if (node.id == draggingNodeId) continue;

      quadtree.calculateForceScalar(
        node,
        config.manyBodyStrength,
        alpha,
        forceAccum,
        distanceMin: config.manyBodyDistanceMin,
        distanceMax: config.manyBodyDistanceMax,
      );
      node.vx += forceAccum.x;
      node.vy += forceAccum.y;
    }

    // Merged loop: linked repulsion correction + link spring forces
    // Computes delta/distance once per link pair instead of twice
    final velocityDecayFactor = 1.0 - config.velocityDecay;

    for (final link in links) {
      final n1 = nodes[link.sourceId];
      final n2 = nodes[link.targetId];
      if (n1 == null || n2 == null) continue;
      if (n1.id == n2.id) continue;

      double dx = n2.px - n1.px;
      double dy = n2.py - n1.py;
      double distance = sqrt(dx * dx + dy * dy);

      if (distance == 0) {
        distance = 0.1;
        dx = 0.1;
        dy = 0;
      }

      final invDist = 1.0 / distance;

      // --- Linked repulsion correction ---
      if (distance <= config.manyBodyDistanceMax &&
          config.linkedRepulsionReduction != 0) {
        final clampedDist = distance < config.manyBodyDistanceMin
            ? config.manyBodyDistanceMin
            : distance;
        final repulsionApprox =
            config.manyBodyStrength * alpha * n2.mass / clampedDist;
        final corrX =
            dx * invDist * repulsionApprox * config.linkedRepulsionReduction;
        final corrY =
            dy * invDist * repulsionApprox * config.linkedRepulsionReduction;

        if (n1.id != draggingNodeId) {
          n1.vx -= corrX;
          n1.vy -= corrY;
        }
        if (n2.id != draggingNodeId) {
          n2.vx += corrX;
          n2.vy += corrY;
        }
      }

      // --- Link spring force ---
      final displacement =
          (distance - config.linkDistance) *
          invDist *
          alpha *
          config.linkStrength;

      final sourceDegree = nodeDegrees[n1.id] ?? 1;
      final targetDegree = nodeDegrees[n2.id] ?? 1;
      final bias = sourceDegree / (sourceDegree + targetDegree);

      if (n2.id != draggingNodeId) {
        n2.vx -= dx * displacement * bias;
        n2.vy -= dy * displacement * bias;
      }
      if (n1.id != draggingNodeId) {
        n1.vx += dx * displacement * (1 - bias);
        n1.vy += dy * displacement * (1 - bias);
      }
    }

    // Gravity force
    for (final node in nodes.values) {
      if (node.id == draggingNodeId) continue;

      final dist = sqrt(node.px * node.px + node.py * node.py);
      // Soft non-linear scaling: sqrt(dist / scale)
      final scaling = sqrt(dist / config.gravityDistanceScale);
      final factor = config.gravityStrength * alpha * node.sqrtMass * scaling;

      node.vx -= node.px * factor;
      node.vy -= node.py * factor;
    }

    // Apply velocity and decay
    for (final node in nodes.values) {
      if (node.id == draggingNodeId) {
        if (node.dragTargetX != null && node.dragTargetY != null) {
          final dx = node.dragTargetX! - node.px;
          final dy = node.dragTargetY! - node.py;

          // Spring force towards target
          final springForce = 0.4;
          node.vx += dx * springForce;
          node.vy += dy * springForce;

          // Stronger damping so it doesn't overshoot repeatedly
          final damping = 0.5;
          node.vx *= damping;
          node.vy *= damping;
        } else {
          node.vx = 0;
          node.vy = 0;
        }

        node.px += node.vx;
        node.py += node.vy;
        continue;
      }

      node.px += node.vx;
      node.py += node.vy;
      node.vx *= velocityDecayFactor;
      node.vy *= velocityDecayFactor;
    }

    frameCount++;
    if (frameCount % 1 == 0) {
      final count = nodes.length;
      final buffer = Float64List(count * 2);

      // We need to maintain a stable list of keys
      final ids = nodes.keys.toList(growable: false);

      for (int i = 0; i < count; i++) {
        final node = nodes[ids[i]];
        if (node != null) {
          buffer[i * 2] = node.px;
          buffer[i * 2 + 1] = node.py;
        }
      }

      sendPort.send(
        PhysicsMessage(PhysicsCommand.updateNodes, {
          'ids': ids,
          'coords': buffer,
        }),
      );
    }
  }

  void startTimer() {
    if (loopTimer != null && loopTimer!.isActive) return;
    loopTimer?.cancel();
    loopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => step());
  }

  void reheat() {
    alpha = config.alphaStart;
    startTimer();
  }

  // Message Loop
  receivePort.listen((message) {
    if (message is PhysicsMessage) {
      switch (message.command) {
        case PhysicsCommand.start:
          startTimer();
          break;

        case PhysicsCommand.stop:
          stopTimer();
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
            recomputeDegrees();
            reheat();
          }
          break;

        case PhysicsCommand.updateNodes:
          if (message.data is List<PhysicsNode>) {
            for (var n in (message.data as List<PhysicsNode>)) {
              nodes[n.id] = n;
            }
            reheat();
          }
          break;

        case PhysicsCommand.removeNode:
          if (message.data is String) {
            final id = message.data as String;
            nodes.remove(id);
            links.removeWhere((l) => l.sourceId == id || l.targetId == id);
            recomputeDegrees();
            reheat();
          }
          break;

        case PhysicsCommand.updateLinks:
          if (message.data is List<PhysicsLinkData>) {
            links.clear();
            links.addAll(message.data as List<PhysicsLinkData>);
            recomputeDegrees();
            reheat();
          }
          break;

        case PhysicsCommand.touchNode:
          final map = message.data as Map;
          final id = map['id'] as String?;
          if (id != null) {
            draggingNodeId = id;
            if (map.containsKey('position')) {
              final pos = map['position'] as Offset;
              nodes[id]?.dragTargetX = pos.dx;
              nodes[id]?.dragTargetY = pos.dy;
            } else {
              nodes[id]?.dragTargetX = nodes[id]?.px;
              nodes[id]?.dragTargetY = nodes[id]?.py;
            }

            reheat();
          } else {
            // End drag cleanly
            if (draggingNodeId != null) {
              nodes[draggingNodeId]?.dragTargetX = null;
              nodes[draggingNodeId]?.dragTargetY = null;
            }
            draggingNodeId = null;
          }
          break;

        case PhysicsCommand.reheat:
          reheat();
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
