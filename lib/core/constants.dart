/// D3-force style physics constants — soft, jelly-like feel.
class AppConstants {
  // Alpha cooling (simulated annealing)
  static const double alphaStart = 0.45;
  static const double alphaMin = 0.001;
  static const double alphaDecay = 0.01;
  static const double alphaTarget = 0.0;

  static const double velocityDecay = 0.2;

  static const double manyBodyStrength = -110.0;
  static const double manyBodyDistanceMin = 1.0;
  static const double manyBodyDistanceMax = 1100.0;
  static const double manyBodyTheta = 0.9;

  static const double linkStrength = 0.035;
  static const double linkDistance = 150.0;

  static const double linkedRepulsionReduction =
      0; // how much repulsion to cancel between linked nodes (0..1)

  // Gravity — pull nodes to center (0,0)
  static const double gravityStrength = 0.02;
  static const double gravityDistanceScale = 10000.0;

  // Mass multiplier per connection
  static const double connectionMassModifier = 0.3;

  // Node appearance animation
  static const double nodeAppearDurationMs = 600.0;
  static const double nodeAppearStaggerMs = 80.0;
}
