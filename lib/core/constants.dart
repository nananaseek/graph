/// D3-force style physics constants — soft, jelly-like feel.
class AppConstants {
  // Alpha cooling (simulated annealing)
  static const double alphaStart = 1.0;
  static const double alphaMin = 0.001;
  static const double alphaDecay = 0.02;
  static const double alphaTarget = 0.0;

  static const double velocityDecay = 0.2;

  static const double manyBodyStrength = -80.0;
  static const double manyBodyDistanceMin = 1.0;
  static const double manyBodyDistanceMax = 1100.0;
  static const double manyBodyTheta = 0.9;

  static const double linkStrength = 0.07;
  static const double linkDistance = 130.0;
  static const double linkedRepulsionReduction =
      0; // how much repulsion to cancel between linked nodes (0..1)

  // Gravity — pull nodes to center (0,0)
  static const double gravityStrength = 0.005;

  // Inertia — how much velocity is preserved when throwing a node (0..1 or more)
  static const double inertiaStrength = 0.03;
}
