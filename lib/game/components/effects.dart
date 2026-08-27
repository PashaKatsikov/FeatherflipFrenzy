import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A quick expanding-and-fading ring, used for hit sparks, water splashes
/// and delivery bursts. Removes itself once finished.
class BurstEffectComponent extends PositionComponent {
  BurstEffectComponent({
    required Vector2 position,
    required this.color,
    this.maxRadius = 40,
    this.duration = 0.45,
    this.filled = false,
  }) : super(position: position, anchor: Anchor.center);

  final Color color;
  final double maxRadius;
  final double duration;
  final bool filled;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final frac = (_t / duration).clamp(0.0, 1.0);
    final radius = maxRadius * (0.25 + 0.75 * frac);
    final opacity = (1 - frac).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}

/// Small floating text, e.g. "+10" coin popups.
class FloatingTextComponent extends PositionComponent {
  FloatingTextComponent({
    required Vector2 position,
    required this.text,
    this.color = Colors.white,
    this.fontSize = 22,
    this.duration = 0.9,
  }) : super(position: position, anchor: Anchor.center);

  final String text;
  final Color color;
  final double fontSize;
  final double duration;
  double _t = 0;

  /// Laid out once: re-measuring text on every frame showed up as jank when
  /// several deliveries landed at the same time.
  late final TextPainter _painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        color: color,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.y -= dt * 42;
    if (_t >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final frac = (_t / duration).clamp(0.0, 1.0);
    final opacity = (1 - frac).clamp(0.0, 1.0);
    canvas.saveLayer(
      Rect.fromCenter(center: Offset.zero, width: _painter.width + 16, height: _painter.height + 16),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));
    canvas.restore();
  }
}
