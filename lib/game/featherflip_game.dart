import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;

import '../core/analytics_service.dart';
import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../models/egg_type.dart';
import '../models/round_result.dart';
import '../models/yard_challenge.dart';
import '../models/zone.dart';
import '../state/app_state.dart';
import 'components/chicken_component.dart';
import 'components/effects.dart';
import 'components/egg_component.dart';
import 'components/grain_pouch_component.dart';
import 'components/nest_glow_component.dart';
import 'components/zone_scene_component.dart';
import 'game_utils.dart';
import 'nest_assist.dart';

/// Root Flame game for a single round played inside one [zone]. Owns all
/// physics, spawning, scoring and progression side-effects for that round.
class FeatherflipGame extends FlameGame<World> {
  FeatherflipGame({
    required this.zone,
    required this.appState,
    required this.onRoundEnd,
    this.challenge,
  }) : super(world: World());

  final ZoneDef zone;
  final AppState appState;
  final YardChallenge? challenge;
  final void Function(RoundResult result) onRoundEnd;

  static const double worldViewHeight = 720;

  late Rect worldBounds;
  late ChickenComponent chicken;
  late ZoneSceneComponent scene;
  final List<EggComponent> eggs = [];
  final List<GrainPouchComponent> pouches = [];
  NestGlowComponent? nestGlow;

  final math.Random _rng = math.Random();

  final ValueNotifier<int> coinsThisRound = ValueNotifier(0);
  final ValueNotifier<int> streak = ValueNotifier(0);
  final ValueNotifier<double> timeRemaining = ValueNotifier(0);
  final ValueNotifier<int> rescueCharges = ValueNotifier(0);
  final ValueNotifier<String?> bannerText = ValueNotifier(null);

  int eggsDeliveredThisRound = 0;
  int bestStreakThisRound = 0;
  double _roundTimeRemaining = 0;
  double _elapsed = 0;
  double _eggSpawnCooldown = 1.2;
  bool _forceGoldenNext = false;
  double _rareNestActiveTimer = 0;
  bool _ended = false;
  final Set<int> _triggeredThresholds = {};
  double _bannerTimer = 0;

  bool get rareNestActive => _rareNestActiveTimer > 0;

  /// Mirrors the "Extra Visual Effects" setting; read once per round so the
  /// physics loop never touches app state.
  late final bool _extraEffects = appState.highGraphics;

  @override
  Future<void> onLoad() async {
    final layout = zone.layout;
    worldBounds = Rect.fromLTWH(0, 0, layout.worldWidth, layout.worldHeight);
    _roundTimeRemaining = _roundSeconds.toDouble();
    timeRemaining.value = _roundTimeRemaining;
    rescueCharges.value = appState.rescueChargesForRound();

    scene = ZoneSceneComponent(zone: zone);
    await world.add(scene);

    chicken = ChickenComponent(
      spriteAsset: appState.selectedSkin.sprite,
      startPosition: offsetToVector(layout.chickenStart),
      facingSign: appState.selectedSkin.flipGameplay ? -1 : 1,
    );
    chicken.worldBounds = worldBounds;
    chicken.dashSpeedMultiplier = appState.dashSpeedMultiplier();
    chicken.dashRangeMultiplier = appState.dashRangeMultiplier();
    chicken.isBlocked = _isChickenBlocked;
    chicken.priority = 6;
    await world.add(chicken);

    final rareNest = layout.nests.where((n) => n.isRareGolden).cast<NestSpec?>().firstOrNull;
    if (rareNest != null) {
      nestGlow = NestGlowComponent(position: offsetToVector(rareNest.position), isActive: () => rareNestActive);
      nestGlow!.priority = 4;
      await world.add(nestGlow!);
    }

    camera.viewfinder.anchor = Anchor.center;
    _updateCameraZoom();
    _snapCameraTo(offsetToVector(layout.chickenStart));

    for (final sp in layout.spawnPoints.take(zone.maxEggsStart)) {
      _spawnEgg(at: sp.position);
    }
    if (challenge != null) {
      _showBanner("${challenge!.title}!");
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _updateCameraZoom();
    }
  }

  void _updateCameraZoom() {
    if (size.y <= 0) return;
    camera.viewfinder.zoom = size.y / worldViewHeight;
  }

  void _snapCameraTo(Vector2 target) {
    camera.viewfinder.position = _clampedCameraCenter(target);
  }

  /// Eased follow: snapping the camera to the chicken every frame made fast
  /// dashes feel jittery.
  void _followCamera(Vector2 target, double dt) {
    final desired = _clampedCameraCenter(target);
    final current = camera.viewfinder.position;
    final t = clampD(dt * 9, 0, 1);
    camera.viewfinder.position = current + (desired - current) * t;
  }

  Vector2 _clampedCameraCenter(Vector2 target) {
    final zoom = camera.viewfinder.zoom == 0 ? 1 : camera.viewfinder.zoom;
    final visibleWidth = size.x / zoom;
    final halfW = visibleWidth / 2;
    double camX;
    if (halfW * 2 >= worldBounds.width) {
      camX = worldBounds.center.dx;
    } else {
      camX = clampD(target.x, worldBounds.left + halfW, worldBounds.right - halfW);
    }
    return Vector2(camX, worldBounds.center.dy);
  }

  /// Solid obstacles and open water stop the chicken, which is what makes
  /// bridges, banks and islands matter when routing an egg.
  bool _isChickenBlocked(Vector2 pos) {
    final layout = zone.layout;
    for (final obstacle in layout.obstacles) {
      final minDist = obstacle.radius + ChickenComponent.radius * 0.6;
      if ((pos - offsetToVector(obstacle.position)).length2 < minDist * minDist) {
        return true;
      }
    }
    for (final water in layout.waterBodies) {
      if (!rectContainsVector(water.rect, pos)) continue;
      final onSafeGround = layout.bridges.any((b) => rectContainsVector(b.safeRect, pos)) ||
          layout.islands.any((i) => rectContainsVector(i.safeRect, pos));
      if (!onSafeGround) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Input (driven by the Flutter joystick overlay)
  // ---------------------------------------------------------------------

  void setMoveDirection(Vector2 dir) {
    if (_ended) return;
    chicken.setMoveDirection(dir);
  }

  void triggerFlickDash() {
    if (_ended) return;
    chicken.triggerDash();
  }

  void stopMoving() {
    chicken.setMoveDirection(Vector2.zero());
  }

  // ---------------------------------------------------------------------
  // Main loop
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    if (_ended) return;
    _elapsed += dt;

    _roundTimeRemaining = math.max(0, _roundTimeRemaining - dt);
    timeRemaining.value = _roundTimeRemaining;

    _stepSpawner(dt);
    _stepChickenCollisions();
    _stepEggPhysics(dt);
    _stepGrainPouches();
    _cleanupEggs();
    if (_rareNestActiveTimer > 0) {
      _rareNestActiveTimer = math.max(0, _rareNestActiveTimer - dt);
    }
    if (_bannerTimer > 0) {
      _bannerTimer -= dt;
      if (_bannerTimer <= 0) bannerText.value = null;
    }

    _followCamera(chicken.position, dt);

    if (_roundTimeRemaining <= 0) {
      _finishRound();
    }
  }

  // ---------------------------------------------------------------------
  // Spawning
  // ---------------------------------------------------------------------

  int get _currentMaxEggs {
    final t = clampD(_elapsed / math.max(1, zone.roundSeconds * 0.75), 0, 1);
    return (zone.maxEggsStart + (zone.maxEggsLate - zone.maxEggsStart) * t).round().clamp(1, 4);
  }

  void _stepSpawner(double dt) {
    _eggSpawnCooldown -= dt;
    final aliveCount = eggs.where((e) => !e.markedForRemoval).length;
    if (aliveCount < _currentMaxEggs && _eggSpawnCooldown <= 0) {
      final layout = zone.layout;
      final sp = layout.spawnPoints[_rng.nextInt(layout.spawnPoints.length)];
      _spawnEgg(at: sp.position);
      _eggSpawnCooldown = 1.5 + _rng.nextDouble() * 1.4;
    }
  }

  int get _roundSeconds {
    if (challenge?.kind == YardChallengeKind.shortShift) {
      return math.max(40, zone.roundSeconds + YardChallengeRules.shortShiftSecondsDelta);
    }
    return zone.roundSeconds;
  }

  int _starGoal(int base) {
    if (challenge?.kind == YardChallengeKind.shortShift) {
      return math.max(1, base - YardChallengeRules.shortShiftGoalRelief);
    }
    return base;
  }

  double get _coinMultiplier =>
      challenge?.kind == YardChallengeKind.heavyHarvest ? YardChallengeRules.heavyHarvestCoinMultiplier : 1.0;

  EggType _pickEggType() {
    if (_forceGoldenNext) {
      _forceGoldenNext = false;
      return EggType.gold;
    }
    final goldenChance = challenge?.kind == YardChallengeKind.goldenHour ? 0.18 : 0.06;
    if (_elapsed > (challenge?.kind == YardChallengeKind.goldenHour ? 8 : 25) && _rng.nextDouble() < goldenChance) {
      return EggType.gold;
    }
    final r = _rng.nextDouble();
    if (challenge?.kind == YardChallengeKind.heavyHarvest) {
      if (r < 0.38) return EggType.heavy;
      if (r < 0.50) return EggType.bouncy;
      return EggType.normal;
    }
    if (_elapsed > 18 && zone.index >= 1) {
      if (r < 0.14) return EggType.bouncy;
      if (r < 0.28) return EggType.heavy;
    } else if (_elapsed > 12) {
      if (r < 0.10) return EggType.bouncy;
    }
    return EggType.normal;
  }

  void _spawnEgg({required Offset at}) {
    final type = _pickEggType();
    final egg = EggComponent(type: type, startPosition: offsetToVector(at));
    egg.priority = 5;
    eggs.add(egg);
    world.add(egg);
  }

  // ---------------------------------------------------------------------
  // Physics
  // ---------------------------------------------------------------------

  void _stepChickenCollisions() {
    for (final egg in eggs) {
      if (egg.markedForRemoval) continue;
      final delta = egg.position - chicken.position;
      final dist = delta.length;
      final minDist = egg.radius + ChickenComponent.radius;
      if (dist < minDist) {
        final normal = dist > 0.001 ? delta / dist : Vector2(1, 0);
        egg.position = chicken.position + normal * minDist;
        final speed = chicken.velocity.length;
        if (speed > 55) {
          final impulseSpeed = speed *
              appState.hitPowerMultiplier() *
              chicken.impulseMultiplier() *
              egg.type.impulseTransfer;
          egg.velocity = normal * impulseSpeed;
          egg.state = EggLifeState.moving;
          egg.waterStuckTimer = 0;
          if (_extraEffects) {
            world.add(BurstEffectComponent(
              position: egg.position.clone(),
              color: chicken.isDashing ? const Color(0xFFFFE08A) : Colors.white,
              maxRadius: chicken.isDashing ? 46 : 30,
            ));
          }
          AudioService.instance.playSfx(chicken.isDashing ? Sfx.chickenDash : Sfx.chickenEggHit);
          if (chicken.isDashing) {
            Haptics.instance.medium();
          } else {
            Haptics.instance.light();
          }
        }
      }
    }
  }

  void _stepEggPhysics(double dt) {
    final layout = zone.layout;
    for (final egg in eggs) {
      if (egg.markedForRemoval) continue;

      if (egg.type == EggType.gold) {
        egg.lifeTimer += dt;
        final lifespan = egg.type.lifespanSeconds ?? 999;
        if (egg.lifeTimer > lifespan) {
          _loseEgg(egg);
          continue;
        }
      }

      if (egg.state != EggLifeState.moving) continue;

      bool inWater = false;
      Offset flow = Offset.zero;
      for (final w in layout.waterBodies) {
        if (!rectContainsVector(w.rect, egg.position)) continue;
        final safe = layout.bridges.any((b) => rectContainsVector(b.safeRect, egg.position)) ||
            layout.islands.any((i) => rectContainsVector(i.safeRect, egg.position));
        if (!safe) {
          inWater = true;
          flow = w.flow;
        }
        break;
      }
      egg.isInWater = inWater;

      if (inWater) {
        egg.velocity += offsetToVector(flow) * dt;
      }

      final frictionCoeff = (egg.type.friction / appState.eggControlMultiplier()) * (inWater ? 1.5 : 1.0);
      egg.velocity *= clampD(1 - frictionCoeff * dt, 0, 1);
      egg.position += egg.velocity * dt;

      for (final obstacle in layout.obstacles) {
        final delta = egg.position - offsetToVector(obstacle.position);
        final dist = delta.length;
        final minDist = obstacle.radius + egg.radius;
        if (dist < minDist && dist > 0.001) {
          final normal = delta / dist;
          egg.position = offsetToVector(obstacle.position) + normal * minDist;
          final speed = egg.velocity.length;
          egg.velocity = normal * speed * egg.type.bounciness + _tangent(normal) * speed * 0.25;
          if (speed > 40) {
            AudioService.instance.playSfx(Sfx.eggBounce, volume: 0.6);
          }
        }
      }

      final r = egg.radius;
      if (egg.position.x < worldBounds.left + r) {
        egg.position.x = worldBounds.left + r;
        egg.velocity.x = egg.velocity.x.abs() * egg.type.bounciness;
      } else if (egg.position.x > worldBounds.right - r) {
        egg.position.x = worldBounds.right - r;
        egg.velocity.x = -egg.velocity.x.abs() * egg.type.bounciness;
      }
      if (egg.position.y < worldBounds.top + r) {
        egg.position.y = worldBounds.top + r;
        egg.velocity.y = egg.velocity.y.abs() * egg.type.bounciness;
      } else if (egg.position.y > worldBounds.bottom - r) {
        egg.position.y = worldBounds.bottom - r;
        egg.velocity.y = -egg.velocity.y.abs() * egg.type.bounciness;
      }

      NestAssist.nudge(
        egg: egg,
        nests: layout.nests,
        rareNestActive: rareNestActive,
        dt: dt,
      );

      for (final nest in layout.nests) {
        if (nest.isRareGolden && !rareNestActive) continue;
        if (NestAssist.isCaught(egg, nest)) {
          _deliverEgg(egg, nest);
          break;
        }
      }
      if (egg.markedForRemoval) continue;

      if (inWater) {
        egg.waterStuckTimer += dt;
        // A drifting egg gets a longer grace period than a stalled one, but
        // it must eventually sink: otherwise eggs pile up against the world
        // edge forever and starve the spawner.
        final graceSeconds = egg.velocity.length < 22 ? 2.0 : 4.5;
        if (egg.waterStuckTimer > graceSeconds) {
          _loseEgg(egg);
        }
      } else {
        egg.waterStuckTimer = 0;
      }
    }
  }

  Vector2 _tangent(Vector2 normal) => Vector2(-normal.y, normal.x);

  void _cleanupEggs() {
    eggs.removeWhere((egg) {
      if (egg.markedForRemoval && egg.removalAnim >= 1) {
        egg.removeFromParent();
        return true;
      }
      return false;
    });
  }

  // ---------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------

  void _deliverEgg(EggComponent egg, NestSpec nest) {
    egg.markedForRemoval = true;
    egg.removalIsDelivery = true;
    egg.state = EggLifeState.delivered;

    final reward = (egg.type.baseReward * nest.rewardMultiplier * _coinMultiplier).round();
    coinsThisRound.value += reward;
    eggsDeliveredThisRound += 1;
    streak.value += 1;
    if (streak.value > bestStreakThisRound) bestStreakThisRound = streak.value;
    appState.addCoins(reward);
    appState.recordEggDelivered(egg.type);
    appState.recordStreak(bestStreakThisRound);
    AnalyticsService.instance.logEvent('egg_delivered', {
      'egg_type': egg.type.name,
      'zone': zone.id,
    });

    if (_extraEffects) {
      world.add(BurstEffectComponent(
        position: offsetToVector(nest.position),
        color: nest.isRareGolden ? const Color(0xFFFFD54A) : ffDeliveryColor,
        maxRadius: 60,
        filled: true,
        duration: 0.5,
      ));
    }
    world.add(FloatingTextComponent(
      position: offsetToVector(nest.position) - Vector2(0, 40),
      text: '+$reward',
      color: const Color(0xFFFFD54A),
    ));
    AudioService.instance.playSfx(Sfx.eggDeliverySuccess);
    AudioService.instance.playSfx(Sfx.coinCollect, volume: 0.7);
    Haptics.instance.medium();

    _handleStreakThresholds();
    _maybeSpawnGrainPouch(nest);
  }

  void _loseEgg(EggComponent egg) {
    egg.markedForRemoval = true;
    egg.removalIsDelivery = false;
    egg.state = EggLifeState.lost;
    if (_extraEffects) {
      world.add(BurstEffectComponent(
        position: egg.position.clone(),
        color: const Color(0xFF7FD8F2),
        maxRadius: 44,
        filled: true,
        duration: 0.4,
      ));
    }
    AudioService.instance.playSfx(Sfx.eggWaterSplash);
    Haptics.instance.heavy();
    streak.value = 0;
    _triggeredThresholds.clear();
    _showBanner('Streak lost!');
  }

  void _handleStreakThresholds() {
    final s = streak.value;
    if (s >= 3 && !_triggeredThresholds.contains(3)) {
      _triggeredThresholds.add(3);
      appState.addCoins(20);
      _showBanner('Feather Streak Bonus! +20');
    }
    if (s >= 5 && !_triggeredThresholds.contains(5)) {
      _triggeredThresholds.add(5);
      _forceGoldenNext = true;
      _showBanner('A Golden Egg is coming!');
    }
    if (s >= 8 && !_triggeredThresholds.contains(8)) {
      _triggeredThresholds.add(8);
      if (nestGlow != null) {
        _rareNestActiveTimer = 8.0;
        _showBanner('Rare Golden Nest is active!');
      } else {
        appState.addCoins(50);
        _showBanner('Amazing Streak! +50');
      }
    } else if (s >= 8 && nestGlow != null) {
      _rareNestActiveTimer = 8.0;
    }
  }

  void _showBanner(String text) {
    bannerText.value = text;
    _bannerTimer = 2.2;
  }

  // ---------------------------------------------------------------------
  // Rescue dash
  // ---------------------------------------------------------------------

  void triggerRescueDash() {
    if (_ended || rescueCharges.value <= 0) return;
    final target = _pickRescueTarget();
    if (target == null) return;
    rescueCharges.value -= 1;
    appState.recordRescueDashUse();

    final nest = _nearestNest(target.position);
    if (nest != null) {
      final dir = offsetToVector(nest.position) - target.position;
      final dist = dir.length;
      if (dist > 1) {
        final speed = clampD(dist / 0.55, 260, 950);
        target.velocity = dir.normalized() * speed;
      }
    } else if (target.velocity.length > 1) {
      target.velocity = target.velocity.normalized() * 700;
    } else {
      target.velocity = Vector2(700, 0);
    }
    target.state = EggLifeState.moving;
    target.waterStuckTimer = 0;
    chicken.forceDashBoost();
    if (_extraEffects) {
      world.add(BurstEffectComponent(position: chicken.position.clone(), color: const Color(0xFFFFE08A), maxRadius: 60));
    }
    AudioService.instance.playSfx(Sfx.rescueDash);
    Haptics.instance.heavy();
    _showBanner('Rescue Dash!');
  }

  EggComponent? _pickRescueTarget() {
    EggComponent? best;
    var bestScore = double.negativeInfinity;
    for (final egg in eggs) {
      if (egg.markedForRemoval) continue;
      var score = egg.isInWater ? 1000.0 : 0.0;
      score -= (egg.position - chicken.position).length * 0.1;
      if (score > bestScore) {
        bestScore = score;
        best = egg;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------
  // Grain pouches
  // ---------------------------------------------------------------------

  static const double _pouchSpawnChance = 0.25;

  void _maybeSpawnGrainPouch(NestSpec nest) {
    if (pouches.where((p) => !p.collected && !p.expired).length >= 3) return;
    if (_rng.nextDouble() >= _pouchSpawnChance) return;
    final pos = _pouchSpawnPosition(nest);
    if (pos == null) return;
    final pouch = GrainPouchComponent(startPosition: pos);
    pouch.priority = 5;
    pouches.add(pouch);
    world.add(pouch);
  }

  Vector2? _pouchSpawnPosition(NestSpec nest) {
    final origin = offsetToVector(nest.position);
    for (var attempt = 0; attempt < 8; attempt++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = 52 + _rng.nextDouble() * 34;
      final candidate = Vector2(
        origin.x + math.cos(angle) * dist,
        origin.y + math.sin(angle) * dist,
      );
      candidate.x = clampD(candidate.x, worldBounds.left + 28, worldBounds.right - 28);
      candidate.y = clampD(candidate.y, worldBounds.top + 28, worldBounds.bottom - 28);
      if (_isChickenBlocked(candidate)) continue;
      return candidate;
    }
    return null;
  }

  void _stepGrainPouches() {
    for (final pouch in pouches) {
      if (pouch.collected || pouch.expired) continue;
      final dist = (pouch.position - chicken.position).length;
      if (dist < GrainPouchComponent.radius + ChickenComponent.radius * 0.72) {
        _collectGrainPouch(pouch);
      }
    }
    pouches.removeWhere((pouch) {
      if (!pouch.collected && !pouch.expired) return false;
      pouch.removeFromParent();
      return true;
    });
  }

  void _collectGrainPouch(GrainPouchComponent pouch) {
    pouch.collected = true;
    final reward = 8 + _rng.nextInt(8);
    coinsThisRound.value += reward;
    appState.addCoins(reward);
    if (_extraEffects) {
      world.add(BurstEffectComponent(
        position: pouch.position.clone(),
        color: const Color(0xFFFFD54A),
        maxRadius: 40,
        filled: true,
        duration: 0.35,
      ));
    }
    world.add(FloatingTextComponent(
      position: pouch.position.clone() - Vector2(0, 28),
      text: '+$reward',
      color: const Color(0xFFFFD54A),
    ));
    AudioService.instance.playSfx(Sfx.coinCollect);
    Haptics.instance.light();
    _showBanner('Grain Pouch! +$reward');
    AnalyticsService.instance.logEvent('grain_pouch_collected', {'coins': reward});
  }

  NestSpec? _nearestNest(Vector2 from) {
    NestSpec? best;
    var bestDist = double.infinity;
    for (final nest in zone.layout.nests) {
      if (nest.isRareGolden && !rareNestActive) continue;
      final d = (offsetToVector(nest.position) - from).length;
      if (d < bestDist) {
        bestDist = d;
        best = nest;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------
  // Round end
  // ---------------------------------------------------------------------

  void _finishRound() {
    if (_ended) return;
    _ended = true;
    chicken.setMoveDirection(Vector2.zero());
    int stars = 0;
    if (eggsDeliveredThisRound >= _starGoal(zone.goal3Star)) {
      stars = 3;
    } else if (eggsDeliveredThisRound >= _starGoal(zone.goal2Star)) {
      stars = 2;
    } else if (eggsDeliveredThisRound >= _starGoal(zone.goal1Star)) {
      stars = 1;
    }
    final unlockedNew = appState.reportZoneResult(zone, stars);
    var challengeBonus = 0;
    if (challenge != null && appState.claimDailyChallengeReward()) {
      challengeBonus = YardChallengeRules.completionBonus;
      AnalyticsService.instance.logEvent('daily_challenge_complete', {
        'zone': zone.id,
        'kind': challenge!.kind.name,
        'stars': stars,
      });
    }
    appState.persistAfterRound();
    AudioService.instance.playSfx(Sfx.roundComplete);
    AnalyticsService.instance.logEvent('round_complete', {
      'zone': zone.id,
      'stars': stars,
      'eggs': eggsDeliveredThisRound,
      'coins': coinsThisRound.value,
      if (challenge != null) 'challenge': challenge!.kind.name,
    });
    onRoundEnd(RoundResult(
      zone: zone,
      eggsDelivered: eggsDeliveredThisRound,
      coinsEarned: coinsThisRound.value,
      bestStreak: bestStreakThisRound,
      stars: stars,
      unlockedNewZone: unlockedNew,
      challengeBonus: challengeBonus,
      challengeTitle: challenge?.title,
    ));
  }

  /// Called by the hosting screen when it is torn down; the HUD notifiers
  /// outlive the Flame component tree otherwise.
  void disposeNotifiers() {
    coinsThisRound.dispose();
    streak.dispose();
    timeRemaining.dispose();
    rescueCharges.dispose();
    bannerText.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

const Color ffDeliveryColor = Color(0xFF8FE07A);
