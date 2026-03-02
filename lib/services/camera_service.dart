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
  VoidCallback? _onComplete;

  /// Expose animating state to disable canvas interactions while camera moves
  final ValueNotifier<bool> isAnimating = ValueNotifier(false);

  /// Must be called once with the TickerProvider (from State mixin).
  void init(TransformationController ctrl, TickerProvider vsync) {
    controller = ctrl;
    _vsync = vsync;
  }

  /// Animate the camera to center on [nodePosition] maintaining current zoom.
  void animateTo(
    Offset nodePosition,
    Size screenSize, {
    VoidCallback? onComplete,
  }) {
    _onComplete = onComplete;
    // Current scale
    final currentScale = controller.value.getMaxScaleOnAxis();

    // Enforce a minimum zoom level (e.g., 0.8) for the TARGET scale
    // If we are zoomed out too far, we want to zoom in.
    final targetScale = currentScale < 0.8 ? 0.8 : currentScale;

    // Translation to center the node on screen using the TARGET scale
    final tx = screenSize.width / 2 - nodePosition.dx * targetScale;
    final ty = screenSize.height / 2 - nodePosition.dy * targetScale;

    final endMatrix = Matrix4.translationValues(tx, ty, 0.0)
      ..multiply(Matrix4.diagonal3Values(targetScale, targetScale, 1.0));

    _startMatrix = controller.value.clone();
    _endMatrix = endMatrix;
    _elapsedMs = 0.0;
    _animationProgress = 0.0;

    _ticker?.dispose();
    _ticker = _vsync?.createTicker(_onTick);
    isAnimating.value = true;
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
      stopAnimation();
    }
  }

  /// Stops the current animation immediately.
  void stopAnimation() {
    if (_ticker?.isActive ?? false) {
      _ticker?.stop();
    }
    isAnimating.value = false;
    _onComplete?.call();
    _onComplete = null;
  }

  void dispose() {
    _ticker?.dispose();
    isAnimating.dispose();
  }
}
