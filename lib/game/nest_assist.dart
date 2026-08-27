import 'package:flame/components.dart';

import '../models/zone.dart';
import 'components/egg_component.dart';
import 'game_utils.dart';

/// Small on-course helper so a well-aimed egg is a little more likely to
/// settle in the nest. Idle eggs and shots flying *away* from a nest are
/// left alone — this is forgiveness, not a magnet cheat.
class NestAssist {
  /// Extra catch radius on top of the nest's own radius, in world pixels.
  static const double extraCatch = 8;

  /// How far outside the nest the nudge may start.
  static const double assistBand = 64;

  /// Eggs slower than this are not steered (avoids sucking resting eggs in).
  static const double minSpeed = 48;

  /// Must already be heading somewhat toward the nest (1 = dead-on).
  static const double minAlignment = 0.28;

  /// Acceleration added toward the nest, scaled by proximity and aim.
  static const double pullAccel = 240;

  static void nudge({
    required EggComponent egg,
    required List<NestSpec> nests,
    required bool rareNestActive,
    required double dt,
  }) {
    if (egg.state != EggLifeState.moving || egg.markedForRemoval) return;
    final speed = egg.velocity.length;
    if (speed < minSpeed) return;

    NestSpec? best;
    Vector2? toNest;
    var bestDist = double.infinity;
    var bestAlign = 0.0;

    for (final nest in nests) {
      if (nest.isRareGolden && !rareNestActive) continue;
      final delta = offsetToVector(nest.position) - egg.position;
      final dist = delta.length;
      if (dist < 0.001 || dist > nest.radius + extraCatch + assistBand) continue;
      final alignment = egg.velocity.dot(delta) / (speed * dist);
      if (alignment < minAlignment) continue;
      if (dist < bestDist) {
        bestDist = dist;
        best = nest;
        toNest = delta;
        bestAlign = alignment;
      }
    }
    if (best == null || toNest == null) return;

    final range = best.radius + extraCatch + assistBand;
    final proximity = (1 - bestDist / range).clamp(0.0, 1.0);
    egg.velocity += toNest.normalized() * (pullAccel * proximity * bestAlign * dt);
  }

  static bool isCaught(EggComponent egg, NestSpec nest) {
    final d = (egg.position - offsetToVector(nest.position)).length;
    return d <= nest.radius + extraCatch;
  }
}
