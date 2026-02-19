import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Service for smooth camera (TransformationController) animations.
///
/// Centers on a node and zooms so the node occupies ~45% of the viewport.
class CameraService {
  late TransformationController controller;
  Ticker? _ticker;
  TickerProvider? _vsync;

  // Animation state
  Matrix4? _startMatrix;
  Matrix4? _endMatrix;
  double _animationProgress = 1.0;
  static const _animationDurationMs = 400.0;
  double _elapsedMs = 0.0;

  /// Must be called once with the TickerProvider (from State mixin).
  void init(TransformationController ctrl, TickerProvider vsync) {
    controller = ctrl;
    _vsync = vsync;
  }

  /// Animate the camera to center on [nodePosition] with zoom such that
  /// a node of [nodeRadius] occupies ~45% of the visible viewport.
  void animateTo(Offset nodePosition, double nodeRadius, Size screenSize) {
    // Target scale: nodeRadius * 2 should be 45% of min(screenWidth, screenHeight)
    final targetDiameter = nodeRadius * 2;
    final targetViewSize = screenSize.shortestSide;
    final targetScale = (targetViewSize * 0.45) / targetDiameter;

    // Clamp scale to InteractiveViewer bounds
    final scale = targetScale.clamp(0.3, 5.0);

    // Translation to center the node on screen
    final tx = screenSize.width / 2 - nodePosition.dx * scale;
    final ty = screenSize.height / 2 - nodePosition.dy * scale;

    final endMatrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);

    _startMatrix = controller.value.clone();
    _endMatrix = endMatrix;
    _elapsedMs = 0.0;
    _animationProgress = 0.0;

    _ticker?.dispose();
    _ticker = _vsync?.createTicker(_onTick);
    _ticker?.start();
  }

  void _onTick(Duration elapsed) {
    _elapsedMs = elapsed.inMicroseconds / 1000.0;
    _animationProgress = (_elapsedMs / _animationDurationMs).clamp(0.0, 1.0);

    // Ease in-out cubic
    final t = _animationProgress < 0.5
        ? 4 * _animationProgress * _animationProgress * _animationProgress
        : 1 -
              (-2 * _animationProgress + 2) *
                  (-2 * _animationProgress + 2) *
                  (-2 * _animationProgress + 2) /
                  2;

    if (_startMatrix != null && _endMatrix != null) {
      // Lerp each element of the 4x4 matrix
      final result = Matrix4.zero();
      for (int i = 0; i < 16; i++) {
        result.storage[i] =
            _startMatrix!.storage[i] +
            (_endMatrix!.storage[i] - _startMatrix!.storage[i]) * t;
      }
      controller.value = result;
    }

    if (_animationProgress >= 1.0) {
      _ticker?.stop();
    }
  }

  void dispose() {
    _ticker?.dispose();
  }
}
