import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game_utils.dart';

/// The player-controlled chicken. A fixed on-screen joystick supplies a
/// direction; speed is constant so the chicken never crawls or surges from
/// analog throw. A quick flick on the stick triggers Feather Flip.
class ChickenComponent extends PositionComponent {
  ChickenComponent({
    required this.spriteAsset,
    required Vector2 startPosition,
    this.facingSign = 1,
  }) : super(
          position: startPosition,
          size: Vector2(96, 96),
          anchor: Anchor.center,
        );

  final String spriteAsset;

  /// 1 if the art already faces right, -1 if it must be mirrored in play.
  final double facingSign;

  static const double walkSpeed = 280;
  static const double baseDashSpeed = 560;
  static const double turnAccel = 9000;
  static const double stopAccel = 4000;
  static const double baseDashDuration = 0.26;
  static const double radius = 34;

  double dashSpeedMultiplier = 1.0;
  double dashRangeMultiplier = 1.0;

  /// Returns true when the chicken cannot stand at [pos] (solid obstacle or
  /// open water). Supplied by the game, which owns the zone layout.
  bool Function(Vector2 pos)? isBlocked;

  Vector2 velocity = Vector2.zero();

  double _dashTimer = 0;
  bool get isDashing => _dashTimer > 0;

  /// Unit vector or zero. Never scaled by analog magnitude.
  final Vector2 _moveDir = Vector2.zero();

  double _wobble = 0;
  late double _facing = facingSign;

  late SpriteComponent _sprite;
  late Rect worldBounds;

  static final Paint _shadowPaint = Paint()..color = const Color(0x33000000);

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load(spriteAsset);
    _sprite = SpriteComponent(sprite: sprite, size: size, anchor: Anchor.center, position: size / 2);
    add(_sprite);
  }

  /// Grounds the chicken in the 3/4 perspective; without it the sprite reads
  /// as floating above the field.
  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x / 2, size.y * 0.86), width: size.x * 0.52, height: size.y * 0.16),
      _shadowPaint,
    );
    super.render(canvas);
  }

  void setMoveDirection(Vector2 dir) {
    if (dir.length2 < 0.0001) {
      _moveDir.setZero();
    } else {
      _moveDir
        ..setFrom(dir)
        ..normalize();
    }
  }

  void triggerDash() {
    _dashTimer = baseDashDuration * dashRangeMultiplier;
  }

  /// Called by the game loop right when the chicken hits an egg, so the
  /// impulse also carries a dash bonus.
  double impulseMultiplier() => isDashing ? 1.55 : 1.0;

  /// Used by the Rescue Dash special ability to give the chicken a brief
  /// visual dash flourish even without a fast pointer flick.
  void forceDashBoost() {
    _dashTimer = math.max(_dashTimer, baseDashDuration * dashRangeMultiplier * 1.6);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_dashTimer > 0) {
      _dashTimer = math.max(0, _dashTimer - dt);
    }

    final speed = isDashing ? baseDashSpeed * dashSpeedMultiplier : walkSpeed;
    final desired = _moveDir.length2 > 0 ? _moveDir * speed : Vector2.zero();
    final accel = _moveDir.length2 > 0 ? turnAccel : stopAccel;
    velocity = moveToward(velocity, desired, accel * dt);

    _applyMovement(velocity * dt);

    if (velocity.x.abs() > 12) {
      _facing = (velocity.x >= 0 ? 1.0 : -1.0) * facingSign;
    }
    _wobble += dt * (isDashing ? 14 : 8);
    final speedFrac = clampD(velocity.length / walkSpeed, 0, 1.6);
    final moving = speedFrac > 0.05 ? 1 : 0;
    final squash = 1 + (isDashing ? 0.10 : 0.04) * math.sin(_wobble) * moving;
    scale = Vector2(_facing * squash, 2 - squash);
  }

  /// Moves by [delta], sliding along blockers instead of stopping dead so the
  /// chicken still feels responsive when hugging a rock or a riverbank.
  void _applyMovement(Vector2 delta) {
    final target = _clampToWorld(position + delta);
    final blocker = isBlocked;
    if (blocker == null || !blocker(target)) {
      position = target;
      return;
    }
    // Already stuck inside a blocker (e.g. layout overlap): let it walk out.
    if (blocker(position)) {
      position = target;
      return;
    }
    final slideX = _clampToWorld(Vector2(position.x + delta.x, position.y));
    if (!blocker(slideX)) {
      position = slideX;
      velocity.y = 0;
      return;
    }
    final slideY = _clampToWorld(Vector2(position.x, position.y + delta.y));
    if (!blocker(slideY)) {
      position = slideY;
      velocity.x = 0;
      return;
    }
    velocity.setZero();
  }

  Vector2 _clampToWorld(Vector2 pos) => Vector2(
        clampD(pos.x, worldBounds.left + radius, worldBounds.right - radius),
        clampD(pos.y, worldBounds.top + radius, worldBounds.bottom - radius),
      );
}
