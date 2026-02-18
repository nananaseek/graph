import '../models/physics_node.dart';

class QuadtreeNode {
  // Scalar boundary — avoids Rect allocations
  double bLeft = 0;
  double bTop = 0;
  double bWidth = 0;
  double bHeight = 0;

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

  QuadtreeNode();

  void setBoundary(double left, double top, double width, double height) {
    bLeft = left;
    bTop = top;
    bWidth = width;
    bHeight = height;
  }

  double get bRight => bLeft + bWidth;
  double get bBottom => bTop + bHeight;
  double get bCenterX => bLeft + bWidth * 0.5;
  double get bCenterY => bTop + bHeight * 0.5;

  void reset(double left, double top, double width, double height) {
    bLeft = left;
    bTop = top;
    bWidth = width;
    bHeight = height;
    comX = 0;
    comY = 0;
    totalMass = 0;
    child0 = null;
    child1 = null;
    child2 = null;
    child3 = null;
    body = null;
    isLeaf = true;
  }

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

class QuadtreeNodePool {
  final List<QuadtreeNode> _pool = [];
  int _index = 0;

  QuadtreeNode acquire(double left, double top, double width, double height) {
    if (_index < _pool.length) {
      final node = _pool[_index++];
      node.reset(left, top, width, height);
      return node;
    }
    final node = QuadtreeNode();
    node.setBoundary(left, top, width, height);
    _pool.add(node);
    _index++;
    return node;
  }

  void releaseAll() => _index = 0;

  int get activeCount => _index;
  int get poolSize => _pool.length;
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
  final double bLeft, bTop, bWidth, bHeight;
  final double thetaSq;
  final QuadtreeNodePool pool;

  Quadtree(
    this.bLeft,
    this.bTop,
    this.bWidth,
    this.bHeight, {
    double theta = 0.9,
    required this.pool,
  }) : thetaSq = theta * theta;

  void insert(PhysicsNode node) {
    if (node.px < bLeft ||
        node.px > bLeft + bWidth ||
        node.py < bTop ||
        node.py > bTop + bHeight) {
      return;
    }
    root = _insertRecursive(root, bLeft, bTop, bWidth, bHeight, node);
  }

  QuadtreeNode _insertRecursive(
    QuadtreeNode? node,
    double left,
    double top,
    double width,
    double height,
    PhysicsNode body,
  ) {
    if (node == null) {
      final newNode = pool.acquire(left, top, width, height);
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
    final cx = node.bCenterX;
    final cy = node.bCenterY;

    // 0: TL, 1: TR, 2: BL, 3: BR
    int index = 0;
    if (body.px > cx) index += 1;
    if (body.py > cy) index += 2;

    final hw = node.bWidth * 0.5;
    final hh = node.bHeight * 0.5;

    double x = node.bLeft;
    double y = node.bTop;

    if (index == 1 || index == 3) x += hw;
    if (index == 2 || index == 3) y += hh;

    final result = _insertRecursive(node.childAt(index), x, y, hw, hh, body);
    node.setChild(index, result);
  }

  void _updateMass(QuadtreeNode node) {
    double massSum = 0;
    double momentX = 0;
    double momentY = 0;

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
    final distMinSq = distanceMin * distanceMin;
    final distMaxSq = distanceMax * distanceMax;
    _addForce(root, target, strength, alpha, distMinSq, distMaxSq, accum);
  }

  void _addForce(
    QuadtreeNode? node,
    PhysicsNode target,
    double strength,
    double alpha,
    double distMinSq,
    double distMaxSq,
    ForceAccum accum,
  ) {
    if (node == null || node.totalMass == 0) return;

    double dx = node.comX - target.px;
    double dy = node.comY - target.py;
    double distSq = dx * dx + dy * dy;

    if (distSq == 0) return;

    double widthSq = node.bWidth * node.bWidth;

    if (node.isLeaf || (widthSq / distSq < thetaSq)) {
      // Skip self
      if (node.isLeaf && node.body == target) return;

      // Clamp via squared distances — avoid sqrt when possible
      if (distSq > distMaxSq) return;
      if (distSq < distMinSq) distSq = distMinSq;

      // D3-style: force = strength * alpha * mass / distance
      // = strength * alpha * mass / sqrt(distSq)
      // Rewritten: dx * invDist * force = dx / dist * strength*alpha*mass / dist
      //          = dx * strength * alpha * mass / distSq
      final forceOverDist = strength * alpha * node.totalMass / distSq;

      accum.x += dx * forceOverDist;
      accum.y += dy * forceOverDist;
      return;
    }

    // Recurse into children — inlined, no List iteration
    if (node.child0 != null) {
      _addForce(
        node.child0,
        target,
        strength,
        alpha,
        distMinSq,
        distMaxSq,
        accum,
      );
    }
    if (node.child1 != null) {
      _addForce(
        node.child1,
        target,
        strength,
        alpha,
        distMinSq,
        distMaxSq,
        accum,
      );
    }
    if (node.child2 != null) {
      _addForce(
        node.child2,
        target,
        strength,
        alpha,
        distMinSq,
        distMaxSq,
        accum,
      );
    }
    if (node.child3 != null) {
      _addForce(
        node.child3,
        target,
        strength,
        alpha,
        distMinSq,
        distMaxSq,
        accum,
      );
    }
  }
}
