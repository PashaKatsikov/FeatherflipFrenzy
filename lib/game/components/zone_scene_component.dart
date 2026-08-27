import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../models/zone.dart';
import '../game_utils.dart';

/// Renders every static piece of a zone (ground, water, banks, bridges,
/// islands, obstacles, decor, nests) in a single component so that the
/// dynamic gameplay layer (chicken/eggs) stays cheap to reason about.
///
/// Water shapes are drawn procedurally from the exact same [Rect]s used for
/// physics, which guarantees the visuals and the collision logic can never
/// drift apart.
class ZoneSceneComponent extends PositionComponent {
  final ZoneDef zone;
  ZoneSceneComponent({required this.zone})
      : super(size: Vector2(zone.layout.worldWidth, zone.layout.worldHeight));

  final Map<String, Sprite> _sprites = {};
  ui.Image? _groundTexture;

  @override
  int get priority => 0;

  @override
  Future<void> onLoad() async {
    final layout = zone.layout;
    final paths = <String>{
      for (final d in layout.decor) d.sprite,
      for (final o in layout.obstacles) o.sprite,
      for (final n in layout.nests) n.sprite,
      for (final b in layout.bridges) b.sprite,
      for (final i in layout.islands) i.sprite,
    };
    await Future.wait(paths.map((p) async {
      _sprites[p] = await Sprite.load(p);
    }));
    _groundTexture = await Flame.images.load(Sprites.groundPasture);
  }

  @override
  void render(Canvas canvas) {
    final layout = zone.layout;
    final worldRect = Rect.fromLTWH(0, 0, size.x, size.y);

    _drawGround(canvas, worldRect);

    for (final water in layout.waterBodies) {
      _drawWater(canvas, water);
    }

    for (final decor in layout.decor) {
      _drawSprite(canvas, decor.sprite, decor.position, Vector2(decor.width, decor.height), decor.rotation);
    }

    for (final obstacle in layout.obstacles) {
      final d = obstacle.radius * 2.6 * obstacle.visualScale;
      _drawSprite(canvas, obstacle.sprite, obstacle.position, Vector2(d, d), 0);
    }

    for (final island in layout.islands) {
      _drawSprite(canvas, island.sprite, island.position, Vector2(island.width, island.height), 0);
    }

    for (final bridge in layout.bridges) {
      _drawSprite(canvas, bridge.sprite, bridge.position, Vector2(bridge.width, bridge.height), bridge.rotation);
    }

    for (final nest in layout.nests) {
      final d = nest.radius * 2.35;
      _drawSprite(canvas, nest.sprite, nest.position, Vector2(d, d), 0);
    }
  }

  void _drawGround(Canvas canvas, Rect worldRect) {
    final texture = _groundTexture;
    if (texture == null) {
      canvas.drawRect(
        worldRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF6FC24A), Color(0xFF4FA83A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(worldRect),
      );
      return;
    }
    // A single copy of the location backdrop covers the whole field.
    // Repeating it (the old tile shader) produced visible seams - four copies
    // of the pasture painting on zone 1 alone.
    final srcW = texture.width.toDouble();
    final srcH = texture.height.toDouble();
    final scale = math.max(worldRect.width / srcW, worldRect.height / srcH);
    final dest = Rect.fromCenter(
      center: worldRect.center,
      width: srcW * scale,
      height: srcH * scale,
    );
    canvas.save();
    canvas.clipRect(worldRect);
    canvas.drawImageRect(
      texture,
      Rect.fromLTWH(0, 0, srcW, srcH),
      dest,
      Paint(),
    );
    canvas.restore();
  }

  void _drawWater(Canvas canvas, WaterBody water) {
    final rect = water.rect;
    final cornerRadius = water.isLake
        ? (rect.shortestSide * 0.32)
        : (rect.shortestSide * 0.42);
    final bankRect = rect.inflate(16);
    final bankRRect = RRect.fromRectAndRadius(bankRect, Radius.circular(cornerRadius + 14));
    canvas.drawRRect(bankRRect, Paint()..color = const Color(0xFFD8C08A));

    final waterRRect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
    final waterPaint = Paint()
      ..shader = LinearGradient(
        colors: water.isLake
            ? const [Color(0xFF3AB6D6), Color(0xFF1D7FA8)]
            : const [Color(0xFF57CBE0), Color(0xFF2D9BC7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(waterRRect, waterPaint);

    canvas.save();
    canvas.clipRRect(waterRRect);
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    if (water.isLake) {
      canvas.drawCircle(rect.center.translate(-rect.width * 0.15, -rect.height * 0.1), rect.shortestSide * 0.28, highlightPaint);
    } else {
      for (double t = 0; t < 1; t += 0.28) {
        final y = rect.top + rect.height * t;
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y + 14), highlightPaint..strokeWidth = 4);
      }
    }
    canvas.restore();
  }

  void _drawSprite(Canvas canvas, String path, Offset position, Vector2 size, double rotation) {
    final sprite = _sprites[path];
    if (sprite == null) return;
    if (rotation == 0) {
      sprite.render(
        canvas,
        position: offsetToVector(position),
        size: size,
        anchor: Anchor.center,
      );
      return;
    }
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    sprite.render(canvas, position: Vector2.zero(), size: size, anchor: Anchor.center);
    canvas.restore();
  }
}
