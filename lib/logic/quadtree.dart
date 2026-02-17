import 'dart:math';
import '../models/physics_node.dart';
import 'dart:ui';

class QuadtreeNode {
  Rect boundary;
  double comX = 0; // center of mass X
  double comY = 0; // center of mass Y
  double totalMass = 0;

  // 4 separate fields instead of List — avoids List allocation & improves locality
  QuadtreeNode? child0; // TL
  QuadtreeNode? child1; // TR
  QuadtreeNode? child2; // BL
  QuadtreeNode? child3; // BR

  PhysicsNode? body;

  // Cached — updated on child insertion instead of recalculating via every()
  bool isLeaf = true;

  QuadtreeNode(this.boundary);

  QuadtreeNode? childAt(int index) {
    switch (index) {
      case 0:
        return child0;
      case 1:
        return child1;
      case 2:
        return child2;
      case 3:
        return child3;
      default:
        return null;
    }
  }

  void setChild(int index, QuadtreeNode node) {
    switch (index) {
      case 0:
        child0 = node;
        break;
      case 1:
        child1 = node;
        break;
      case 2:
        child2 = node;
        break;
      case 3:
        child3 = node;
        break;
    }
    isLeaf = false;
  }
}

/// Mutable force accumulator — avoids Offset allocations in recursion.
/// Safe for single-threaded use in isolate.
class ForceAccum {
  double x = 0;
  double y = 0;

  void reset() {
    x = 0;
    y = 0;
  }
}

class Quadtree {
  QuadtreeNode? root;
  final Rect boundary;
  final double theta;

  Quadtree(this.boundary, {this.theta = 0.9});

  void insert(PhysicsNode node) {
    if (node.px < boundary.left ||
        node.px > boundary.right ||
        node.py < boundary.top ||
        node.py > boundary.bottom) {
      return;
    }
    root = _insertRecursive(root, boundary, node);
  }

  QuadtreeNode _insertRecursive(
    QuadtreeNode? node,
    Rect boundary,
    PhysicsNode body,
  ) {
    if (node == null) {
      final newNode = QuadtreeNode(boundary);
      newNode.body = body;
      newNode.comX = body.px;
      newNode.comY = body.py;
      newNode.totalMass = body.mass;
      return newNode;
    }

    if (node.isLeaf && node.body != null) {
      final dx = node.body!.px - body.px;
      final dy = node.body!.py - body.py;
      if (dx * dx + dy * dy < 0.000001) {
        // Near-coincident bodies — jitter slightly to avoid infinite subdivision
        body.px += 0.1;
        body.py += 0.1;
      }

      final oldBody = node.body!;
      node.body = null;

      _insertToChild(node, oldBody);
      _insertToChild(node, body);
    } else {
      _insertToChild(node, body);
    }

    _updateMass(node);
    return node;
  }

  void _insertToChild(QuadtreeNode node, PhysicsNode body) {
    final cx = node.boundary.center.dx;
    final cy = node.boundary.center.dy;

    // 0: TL, 1: TR, 2: BL, 3: BR
    int index = 0;
    if (body.px > cx) index += 1;
    if (body.py > cy) index += 2;

    double x = node.boundary.left;
    double y = node.boundary.top;
    double w = node.boundary.width / 2;
    double h = node.boundary.height / 2;

    if (index == 1 || index == 3) x += w;
    if (index == 2 || index == 3) y += h;

    final childRect = Rect.fromLTWH(x, y, w, h);
    final result = _insertRecursive(node.childAt(index), childRect, body);
    node.setChild(index, result);
  }

  void _updateMass(QuadtreeNode node) {
    double massSum = 0;
    double momentX = 0;
    double momentY = 0;

    // Inline iteration over 4 fields — no List/iterator overhead
    final c0 = node.child0;
    if (c0 != null) {
      massSum += c0.totalMass;
      momentX += c0.comX * c0.totalMass;
      momentY += c0.comY * c0.totalMass;
    }
    final c1 = node.child1;
    if (c1 != null) {
      massSum += c1.totalMass;
      momentX += c1.comX * c1.totalMass;
      momentY += c1.comY * c1.totalMass;
    }
    final c2 = node.child2;
    if (c2 != null) {
      massSum += c2.totalMass;
      momentX += c2.comX * c2.totalMass;
      momentY += c2.comY * c2.totalMass;
    }
    final c3 = node.child3;
    if (c3 != null) {
      massSum += c3.totalMass;
      momentX += c3.comX * c3.totalMass;
      momentY += c3.comY * c3.totalMass;
    }

    if (massSum > 0) {
      node.totalMass = massSum;
      node.comX = momentX / massSum;
      node.comY = momentY / massSum;
    }
  }

  /// Calculates D3-style many-body force using Barnes-Hut approximation.
  /// Accumulates result into [accum] to avoid Offset allocations.
  /// [strength] should be negative for repulsion.
  void calculateForceScalar(
    PhysicsNode target,
    double strength,
    double alpha,
    ForceAccum accum, {
    double distanceMin = 1.0,
    double distanceMax = 1000.0,
  }) {
    accum.reset();
    _addForce(root, target, strength, alpha, distanceMin, distanceMax, accum);
  }

  void _addForce(
    QuadtreeNode? node,
    PhysicsNode target,
    double strength,
    double alpha,
    double distanceMin,
    double distanceMax,
    ForceAccum accum,
  ) {
    if (node == null || node.totalMass == 0) return;

    double dx = node.comX - target.px;
    double dy = node.comY - target.py;
    double distSq = dx * dx + dy * dy;

    if (distSq == 0) return;

    double distance = sqrt(distSq);
    double width = node.boundary.width;

    if (node.isLeaf || (width / distance < theta)) {
      // Skip self
      if (node.isLeaf && node.body == target) return;

      // Clamp distance
      if (distance < distanceMin) distance = distanceMin;
      if (distance > distanceMax) return;

      // D3-style: force = strength * alpha * mass / distance
      final forceValue = strength * alpha * node.totalMass / distance;
      final invDist = 1.0 / distance;

      accum.x += dx * invDist * forceValue;
      accum.y += dy * invDist * forceValue;
      return;
    }

    // Recurse into children — inlined, no List iteration
    if (node.child0 != null) {
      _addForce(
        node.child0,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
        accum,
      );
    }
    if (node.child1 != null) {
      _addForce(
        node.child1,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
        accum,
      );
    }
    if (node.child2 != null) {
      _addForce(
        node.child2,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
        accum,
      );
    }
    if (node.child3 != null) {
      _addForce(
        node.child3,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
        accum,
      );
    }
  }
}
