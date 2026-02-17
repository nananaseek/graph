import 'dart:ui';
import '../models/physics_node.dart';

class QuadtreeNode {
  Rect boundary;
  Offset centerOfMass = Offset.zero;
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

class Quadtree {
  QuadtreeNode? root;
  final Rect boundary;
  final double theta;

  Quadtree(this.boundary, {this.theta = 0.9});

  void insert(PhysicsNode node) {
    if (!boundary.contains(node.position)) return;
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
      newNode.centerOfMass = body.position;
      newNode.totalMass = body.mass;
      return newNode;
    }

    if (node.isLeaf && node.body != null) {
      if ((node.body!.position - body.position).distance < 0.001) {
        // Near-coincident bodies — jitter slightly to avoid infinite subdivision
        body.position = body.position + const Offset(0.1, 0.1);
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
    if (body.position.dx > cx) index += 1;
    if (body.position.dy > cy) index += 2;

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
      momentX += c0.centerOfMass.dx * c0.totalMass;
      momentY += c0.centerOfMass.dy * c0.totalMass;
    }
    final c1 = node.child1;
    if (c1 != null) {
      massSum += c1.totalMass;
      momentX += c1.centerOfMass.dx * c1.totalMass;
      momentY += c1.centerOfMass.dy * c1.totalMass;
    }
    final c2 = node.child2;
    if (c2 != null) {
      massSum += c2.totalMass;
      momentX += c2.centerOfMass.dx * c2.totalMass;
      momentY += c2.centerOfMass.dy * c2.totalMass;
    }
    final c3 = node.child3;
    if (c3 != null) {
      massSum += c3.totalMass;
      momentX += c3.centerOfMass.dx * c3.totalMass;
      momentY += c3.centerOfMass.dy * c3.totalMass;
    }

    if (massSum > 0) {
      node.totalMass = massSum;
      node.centerOfMass = Offset(momentX / massSum, momentY / massSum);
    }
  }

  /// D3-style many-body force using Barnes-Hut approximation.
  /// Uses inverse-linear falloff: force ∝ strength * alpha / distance
  /// [strength] should be negative for repulsion.
  Offset calculateForce(
    PhysicsNode target,
    double strength,
    double alpha, {
    double distanceMin = 1.0,
    double distanceMax = 1000.0,
  }) {
    return _calculateForceRecursive(
      root,
      target,
      strength,
      alpha,
      distanceMin,
      distanceMax,
    );
  }

  Offset _calculateForceRecursive(
    QuadtreeNode? node,
    PhysicsNode target,
    double strength,
    double alpha,
    double distanceMin,
    double distanceMax,
  ) {
    if (node == null || node.totalMass == 0) return Offset.zero;

    Offset delta = node.centerOfMass - target.position;
    double distance = delta.distance;

    if (distance == 0) return Offset.zero;

    double width = node.boundary.width;

    if (node.isLeaf || (width / distance < theta)) {
      // Skip self
      if (node.isLeaf && node.body == target) return Offset.zero;

      // Clamp distance
      if (distance < distanceMin) distance = distanceMin;
      if (distance > distanceMax) return Offset.zero;

      // D3-style: force = strength * alpha * mass / distance
      // strength is negative → repulsion pushes away from center of mass
      final forceValue = strength * alpha * node.totalMass / distance;

      // Use already-computed distance for normalization instead of delta.distance again
      return (delta / distance) * forceValue;
    }

    // Recurse into children — inlined, no List iteration
    Offset totalForce = Offset.zero;
    if (node.child0 != null) {
      totalForce += _calculateForceRecursive(
        node.child0,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
      );
    }
    if (node.child1 != null) {
      totalForce += _calculateForceRecursive(
        node.child1,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
      );
    }
    if (node.child2 != null) {
      totalForce += _calculateForceRecursive(
        node.child2,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
      );
    }
    if (node.child3 != null) {
      totalForce += _calculateForceRecursive(
        node.child3,
        target,
        strength,
        alpha,
        distanceMin,
        distanceMax,
      );
    }
    return totalForce;
  }
}
