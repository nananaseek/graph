import 'dart:ui';
import '../models/physics_node.dart';

class QuadtreeNode {
  Rect boundary;
  Offset centerOfMass = Offset.zero;
  double totalMass = 0;
  List<QuadtreeNode?> children = List.filled(4, null);
  PhysicsNode? body;

  QuadtreeNode(this.boundary);

  bool get isLeaf => children.every((child) => child == null);
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

    if (node.children.every((c) => c == null) && node.body != null) {
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

    node.children[index] = _insertRecursive(
      node.children[index],
      Rect.fromLTWH(x, y, w, h),
      body,
    );
  }

  void _updateMass(QuadtreeNode node) {
    double massSum = 0;
    double momentX = 0;
    double momentY = 0;

    for (var child in node.children) {
      if (child != null) {
        massSum += child.totalMass;
        momentX += child.centerOfMass.dx * child.totalMass;
        momentY += child.centerOfMass.dy * child.totalMass;
      }
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

      // delta points from target to node → forceValue is negative → pushes away
      return (delta / delta.distance) * forceValue;
    }

    // Recurse into children
    Offset totalForce = Offset.zero;
    for (var child in node.children) {
      totalForce += _calculateForceRecursive(
        child,
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
