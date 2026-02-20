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

  /// Animate the camera to center on [nodePosition] maintaining current zoom.
  void animateTo(Offset nodePosition, Size screenSize) {
    // Keep current scale
    final scale = controller.value.getMaxScaleOnAxis();

    // Translation to center the node on screen
    final tx = screenSize.width / 2 - nodePosition.dx * scale;
    final ty = screenSize.height / 2 - nodePosition.dy * scale;

    final endMatrix = Matrix4.translationValues(tx, ty, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));

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
