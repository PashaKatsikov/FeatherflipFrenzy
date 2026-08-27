import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/assets.dart';
import '../game_utils.dart';

/// A short-lived coin bag that pops out of a nest after a delivery. The
/// chicken collects it by walking over it — no Feather Flip required.
class GrainPouchComponent extends PositionComponent {
  GrainPouchComponent({required Vector2 startPosition})
      : super(
          position: startPosition,
          size: Vector2(48, 48),
          anchor: Anchor.center,
        );

  static const double radius = 22;
  static const double lifetime = 6.0;

  double life = lifetime;
  bool collected = false;
  bool expired = false;
  double spawnAnim = 0;
  double _bobPhase = math.Random().nextDouble() * math.pi * 2;

  late SpriteComponent _sprite;

  static final Paint _shadowPaint = Paint()..color = const Color(0x2E000000);

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load(Sprites.grainPouch);
    _sprite = SpriteComponent(
      sprite: sprite,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_sprite);
  }

  @override
  void render(Canvas canvas) {
    if (!expired && !collected) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.x / 2, size.y * 0.92), width: size.x * 0.7, height: size.y * 0.22),
        _shadowPaint,
      );
    }
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    spawnAnim = clampD(spawnAnim + dt * 5, 0, 1);
    if (collected || expired) {
      return;
    }
    life -= dt;
    _bobPhase += dt * 3.2;
    _sprite.position = size / 2 + Vector2(0, math.sin(_bobPhase) * 3);
    final fade = life < 1.2 ? clampD(life / 1.2, 0.25, 1) : 1.0;
    scale = Vector2.all(spawnAnim * fade);
    if (life <= 0) {
      expired = true;
    }
  }
}
