import 'dart:ui';

/// Lightweight node representation for physics calculations in Isolate.
class PhysicsNode {
  final String id;
  Offset position;
  Offset velocity;
  double mass;
  double radius;

  PhysicsNode({
    required this.id,
    required this.position,
    this.velocity = Offset.zero,
    this.mass = 1.0,
    this.radius = 18.0,
  });

  // Clone method for safe passing between isolates if needed
  PhysicsNode copy() {
    return PhysicsNode(
      id: id,
      position: position,
      velocity: velocity,
      mass: mass,
      radius: radius,
    );
  }
}
