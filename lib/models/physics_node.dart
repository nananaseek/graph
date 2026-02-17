import 'dart:ui';

/// Lightweight node representation for physics calculations in Isolate.
/// Uses scalar doubles instead of Offset to avoid immutable object allocations.
class PhysicsNode {
  final String id;
  double px;
  double py;
  double vx;
  double vy;
  double mass;
  double radius;

  PhysicsNode({
    required this.id,
    required Offset position,
    this.vx = 0.0,
    this.vy = 0.0,
    this.mass = 1.0,
    this.radius = 18.0,
  }) : px = position.dx,
       py = position.dy;

  PhysicsNode._raw({
    required this.id,
    required this.px,
    required this.py,
    this.vx = 0.0,
    this.vy = 0.0,
    this.mass = 1.0,
    this.radius = 18.0,
  });

  Offset get position => Offset(px, py);

  // Clone method for safe passing between isolates if needed
  PhysicsNode copy() {
    return PhysicsNode._raw(
      id: id,
      px: px,
      py: py,
      vx: vx,
      vy: vy,
      mass: mass,
      radius: radius,
    );
  }
}
