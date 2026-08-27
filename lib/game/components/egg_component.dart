import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/egg_type.dart';
import '../game_utils.dart';

enum EggLifeState { idle, moving, delivered, lost }

/// A single egg on the field. Movement/physics is entirely driven by the
/// owning game's update loop (friction, water current, obstacle bounces);
/// this component only tracks state and renders itself.
class EggComponent extends PositionComponent {
  EggComponent({required this.type, required Vector2 startPosition})
      : super(
          position: startPosition,
          size: Vector2(type.radius * 2, type.radius * 2),
          anchor: Anchor.center,
        );

  final EggType type;

  Vector2 velocity = Vector2.zero();
  EggLifeState state = EggLifeState.idle;
  bool isInWater = false;
  double waterStuckTimer = 0;
  double lifeTimer = 0;
  double spawnAnim = 0;
  double removalAnim = 0;
  bool markedForRemoval = false;
  bool removalIsDelivery = false;
  bool lastHitWasDash = false;

  double _bobPhase = math.Random().nextDouble() * math.pi * 2;

  late SpriteComponent _sprite;

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load(type.sprite);
    // Egg artwork is naturally taller than wide; scale it to match the
    // physics diameter on the width axis and keep its native aspect ratio
    // so eggs look like eggs instead of being squashed into circles.
    final aspect = sprite.srcSize.y / sprite.srcSize.x;
    final spriteSize = Vector2(size.x, size.x * aspect);
    _sprite = SpriteComponent(
      sprite: sprite,
      size: spriteSize,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_sprite);
  }

  bool get isAlive => !markedForRemoval;

  double get radius => type.radius;

  static final Paint _shadowPaint = Paint()..color = const Color(0x2E000000);

  @override
  void render(Canvas canvas) {
    if (!isInWater) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.x / 2, size.y * 0.92), width: size.x * 0.72, height: size.y * 0.22),
        _shadowPaint,
      );
    }
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    spawnAnim = clampD(spawnAnim + dt * 4, 0, 1);
    if (markedForRemoval) {
      removalAnim += dt * 3.2;
      final t = clampD(removalAnim, 0, 1);
      final s = removalIsDelivery ? (1 + t * 0.6) * (1 - t) : (1 - t);
      scale = Vector2.all(math.max(0.0, s) * spawnAnim);
      return;
    }

    if (state == EggLifeState.idle) {
      _bobPhase += dt * 2.2;
      _sprite.position = size / 2 + Vector2(0, math.sin(_bobPhase) * 2.4);
    } else {
      _sprite.position = size / 2;
    }

    final spawnScale = spawnAnim;
    scale = Vector2.all(spawnScale);

    if (velocity.length > 4) {
      angle += velocity.x * dt * 0.0018;
    }
  }
}
