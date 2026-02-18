import 'dart:math';
import 'dart:ui';

class PhysicsNode {
  final String id;
  double px;
  double py;
  double vx;
  double vy;
  double mass;
  double radius;

  double sqrtMass;

  PhysicsNode({
    required this.id,
    required Offset position,
    this.vx = 0.0,
    this.vy = 0.0,
    this.mass = 1.0,
    this.radius = 18.0,
  }) : px = position.dx,
       py = position.dy,
       sqrtMass = sqrt(1.0) {
    sqrtMass = sqrt(mass);
  }

  PhysicsNode._raw({
    required this.id,
    required this.px,
    required this.py,
    this.vx = 0.0,
    this.vy = 0.0,
    this.mass = 1.0,
    this.radius = 18.0,
  }) : sqrtMass = sqrt(1.0) {
    sqrtMass = sqrt(mass);
  }

  Offset get position => Offset(px, py);

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
