import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Pulsing golden glow drawn above the rare nest whenever the Feather Streak
/// reward window is active.
class NestGlowComponent extends PositionComponent {
  NestGlowComponent({required Vector2 position, required this.isActive})
      : super(position: position, size: Vector2.all(140), anchor: Anchor.center);

  final bool Function() isActive;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt * 3.4;
  }

  @override
  void render(Canvas canvas) {
    if (!isActive()) return;
    final pulse = 0.75 + 0.25 * math.sin(_t);
    final center = size / 2;
    for (var i = 0; i < 3; i++) {
      final radius = (40 + i * 16) * pulse;
      canvas.drawCircle(
        Offset(center.x, center.y),
        radius,
        Paint()
          ..color = const Color(0xFFFFD54A).withValues(alpha: 0.22 - i * 0.05)
          ..style = PaintingStyle.fill,
      );
    }
  }
}
