import 'package:flutter/material.dart';
import '../core/assets.dart';

class DecorPiece {
  final String sprite;
  final Offset position;
  final double width;
  final double height;
  final double rotation;

  const DecorPiece({
    required this.sprite,
    required this.position,
    required this.width,
    required this.height,
    this.rotation = 0,
  });
}

/// A solid obstacle that redirects eggs on collision.
class ObstacleSpec {
  final String sprite;
  final Offset position;
  final double radius;
  final double visualScale;

  const ObstacleSpec({
    required this.sprite,
    required this.position,
    required this.radius,
    this.visualScale = 1.0,
  });
}

class NestSpec {
  final String sprite;
  final Offset position;
  final double radius;
  final double rewardMultiplier;
  final bool isRareGolden;

  const NestSpec({
    required this.sprite,
    required this.position,
    this.radius = 46,
    this.rewardMultiplier = 1.0,
    this.isRareGolden = false,
  });
}

/// A rectangular body of water with a current that pushes eggs along
/// [flow]. Bridges/islands that overlap a water body act as safe dry
/// ground even though they are geometrically inside the rect.
class WaterBody {
  final Rect rect;
  final Offset flow;
  final bool isLake;

  const WaterBody({required this.rect, required this.flow, this.isLake = false});
}

class BridgeSpec {
  final String sprite;
  final Offset position;
  final double width;
  final double height;
  final double rotation;
  /// Safe rectangle (in world space) that overrides water beneath the bridge.
  final Rect safeRect;

  const BridgeSpec({
    required this.sprite,
    required this.position,
    required this.width,
    required this.height,
    required this.safeRect,
    this.rotation = 0,
  });
}

class IslandSpec {
  final String sprite;
  final Offset position;
  final double width;
  final double height;
  final Rect safeRect;

  const IslandSpec({
    required this.sprite,
    required this.position,
    required this.width,
    required this.height,
    required this.safeRect,
  });
}

class EggSpawnPoint {
  final Offset position;
  const EggSpawnPoint(this.position);
}

class ZoneLayout {
  final double worldWidth;
  final double worldHeight;
  final List<DecorPiece> decor;
  final List<ObstacleSpec> obstacles;
  final List<NestSpec> nests;
  final List<WaterBody> waterBodies;
  final List<BridgeSpec> bridges;
  final List<IslandSpec> islands;
  final List<EggSpawnPoint> spawnPoints;
  final Offset chickenStart;

  const ZoneLayout({
    required this.worldWidth,
    required this.worldHeight,
    this.decor = const [],
    this.obstacles = const [],
    this.nests = const [],
    this.waterBodies = const [],
    this.bridges = const [],
    this.islands = const [],
    required this.spawnPoints,
    required this.chickenStart,
  });
}

class ZoneDef {
  final String id;
  final int index;
  final String name;
  final String description;
  final String vistaSprite;
  final int roundSeconds;
  final int maxEggsStart;
  final int maxEggsLate;
  final int goal1Star;
  final int goal2Star;
  final int goal3Star;
  final ZoneLayout layout;

  const ZoneDef({
    required this.id,
    required this.index,
    required this.name,
    required this.description,
    required this.vistaSprite,
    required this.roundSeconds,
    required this.maxEggsStart,
    required this.maxEggsLate,
    required this.goal1Star,
    required this.goal2Star,
    required this.goal3Star,
    required this.layout,
  });
}

final List<ZoneDef> kZones = [
  ZoneDef(
    id: 'sunny_pasture',
    index: 0,
    name: 'Sunny Pasture',
    description: 'A wide open field. Perfect place to learn the Feather Flip.',
    vistaSprite: Sprites.pastureVista,
    roundSeconds: 70,
    maxEggsStart: 1,
    maxEggsLate: 2,
    goal1Star: 2,
    goal2Star: 4,
    goal3Star: 6,
    layout: ZoneLayout(
      worldWidth: 1720,
      worldHeight: 720,
      chickenStart: const Offset(260, 380),
      spawnPoints: const [EggSpawnPoint(Offset(210, 330)), EggSpawnPoint(Offset(230, 460))],
      decor: [
        const DecorPiece(sprite: Sprites.treeRound, position: Offset(90, 120), width: 130, height: 150),
        const DecorPiece(sprite: Sprites.treeLayered, position: Offset(1500, 130), width: 150, height: 180),
        const DecorPiece(sprite: Sprites.treeFruit, position: Offset(1520, 600), width: 150, height: 180),
        const DecorPiece(sprite: Sprites.treeWillow, position: Offset(80, 610), width: 150, height: 150),
        const DecorPiece(sprite: Sprites.plantWildflowers, position: Offset(420, 600), width: 90, height: 90),
        const DecorPiece(sprite: Sprites.plantFlowerbush, position: Offset(900, 640), width: 90, height: 80),
        const DecorPiece(sprite: Sprites.plantGrass, position: Offset(650, 110), width: 70, height: 90),
        const DecorPiece(sprite: Sprites.plantLeafy, position: Offset(1250, 620), width: 80, height: 80),
        const DecorPiece(sprite: Sprites.coop, position: Offset(150, 200), width: 210, height: 190),
        const DecorPiece(sprite: Sprites.gate, position: Offset(120, 550), width: 170, height: 120),
        const DecorPiece(sprite: Sprites.haystack, position: Offset(300, 610), width: 100, height: 95),
        const DecorPiece(sprite: Sprites.pathStraight, position: Offset(500, 380), width: 260, height: 120, rotation: 1.5708),
      ],
      obstacles: const [
        ObstacleSpec(sprite: Sprites.obstacleBush, position: Offset(620, 250), radius: 34),
        ObstacleSpec(sprite: Sprites.obstacleRock, position: Offset(880, 500), radius: 32),
        ObstacleSpec(sprite: Sprites.obstacleStump, position: Offset(1120, 260), radius: 30),
        ObstacleSpec(sprite: Sprites.obstacleBush, position: Offset(760, 560), radius: 32),
      ],
      nests: const [
        NestSpec(sprite: Sprites.nestPlain, position: Offset(760, 210)),
        NestSpec(sprite: Sprites.nestRoped, position: Offset(1180, 480), rewardMultiplier: 1.1),
      ],
    ),
  ),
  ZoneDef(
    id: 'river_meadow',
    index: 1,
    name: 'River Meadow',
    description: 'A river now crosses the field. Use the bridges wisely.',
    vistaSprite: Sprites.riverVista,
    roundSeconds: 80,
    maxEggsStart: 1,
    maxEggsLate: 3,
    goal1Star: 2,
    goal2Star: 4,
    goal3Star: 6,
    layout: ZoneLayout(
      worldWidth: 2100,
      worldHeight: 720,
      chickenStart: const Offset(260, 380),
      spawnPoints: const [EggSpawnPoint(Offset(210, 320)), EggSpawnPoint(Offset(230, 480))],
      waterBodies: const [
        WaterBody(rect: Rect.fromLTWH(880, -20, 200, 760), flow: Offset(0, 55)),
      ],
      bridges: const [
        BridgeSpec(
          sprite: Sprites.bridgeSmall,
          position: Offset(980, 150),
          width: 210,
          height: 140,
          safeRect: Rect.fromLTWH(870, 90, 220, 130),
        ),
        BridgeSpec(
          sprite: Sprites.bridgeLong,
          position: Offset(980, 530),
          width: 240,
          height: 150,
          safeRect: Rect.fromLTWH(870, 470, 220, 130),
        ),
      ],
      decor: [
        const DecorPiece(sprite: Sprites.coop, position: Offset(150, 200), width: 200, height: 180),
        const DecorPiece(sprite: Sprites.gate, position: Offset(130, 560), width: 160, height: 110),
        const DecorPiece(sprite: Sprites.haystack, position: Offset(300, 600), width: 95, height: 90),
        const DecorPiece(sprite: Sprites.treeRound, position: Offset(60, 90), width: 120, height: 140),
        const DecorPiece(sprite: Sprites.treeLayered, position: Offset(2020, 100), width: 150, height: 175),
        const DecorPiece(sprite: Sprites.treeFruit, position: Offset(2030, 620), width: 150, height: 175),
        const DecorPiece(sprite: Sprites.riverbankReeds, position: Offset(845, 40), width: 55, height: 90),
        const DecorPiece(sprite: Sprites.riverbankReeds, position: Offset(1105, 260), width: 55, height: 90),
        const DecorPiece(sprite: Sprites.riverbankRocks, position: Offset(855, 350), width: 80, height: 60),
        const DecorPiece(sprite: Sprites.riverbankDriftwood, position: Offset(1100, 620), width: 90, height: 70),
        const DecorPiece(sprite: Sprites.riverbankPost, position: Offset(1120, 90), width: 40, height: 65),
        const DecorPiece(sprite: Sprites.riverbankPost, position: Offset(845, 620), width: 40, height: 65),
        const DecorPiece(sprite: Sprites.plantWildflowers, position: Offset(520, 630), width: 85, height: 85),
        const DecorPiece(sprite: Sprites.plantFlowerbush, position: Offset(1650, 610), width: 85, height: 75),
        const DecorPiece(sprite: Sprites.plantGrass, position: Offset(1700, 130), width: 65, height: 85),
      ],
      obstacles: const [
        ObstacleSpec(sprite: Sprites.obstacleRock, position: Offset(560, 240), radius: 32),
        ObstacleSpec(sprite: Sprites.obstacleBush, position: Offset(640, 560), radius: 33),
        ObstacleSpec(sprite: Sprites.obstacleStump, position: Offset(1400, 220), radius: 30),
        ObstacleSpec(sprite: Sprites.obstacleFence, position: Offset(1550, 520), radius: 36),
      ],
      nests: const [
        NestSpec(sprite: Sprites.nestPlain, position: Offset(560, 380)),
        NestSpec(sprite: Sprites.nestRoped, position: Offset(1450, 150), rewardMultiplier: 1.2),
        NestSpec(sprite: Sprites.nestFloral, position: Offset(1780, 480), rewardMultiplier: 1.25),
      ],
    ),
  ),
  ZoneDef(
    id: 'bridge_fields',
    index: 2,
    name: 'Bridge Fields',
    description: 'Two rivers, narrow crossings. Precision matters here.',
    vistaSprite: Sprites.riverVista,
    roundSeconds: 85,
    maxEggsStart: 2,
    maxEggsLate: 3,
    goal1Star: 2,
    goal2Star: 4,
    goal3Star: 6,
    layout: ZoneLayout(
      worldWidth: 2300,
      worldHeight: 720,
      chickenStart: const Offset(260, 380),
      spawnPoints: const [
        EggSpawnPoint(Offset(210, 300)),
        EggSpawnPoint(Offset(230, 480)),
        EggSpawnPoint(Offset(260, 640)),
      ],
      waterBodies: const [
        WaterBody(rect: Rect.fromLTWH(640, -20, 170, 760), flow: Offset(0, 50)),
        WaterBody(rect: Rect.fromLTWH(1480, -20, 170, 760), flow: Offset(0, -50)),
      ],
      bridges: const [
        BridgeSpec(
          sprite: Sprites.bridgeSmall,
          position: Offset(725, 600),
          width: 190,
          height: 130,
          safeRect: Rect.fromLTWH(630, 545, 200, 120),
        ),
        BridgeSpec(
          sprite: Sprites.bridgeSmall,
          position: Offset(1565, 130),
          width: 190,
          height: 130,
          safeRect: Rect.fromLTWH(1470, 75, 200, 120),
        ),
      ],
      decor: [
        const DecorPiece(sprite: Sprites.coop, position: Offset(150, 200), width: 190, height: 170),
        const DecorPiece(sprite: Sprites.gate, position: Offset(130, 560), width: 150, height: 105),
        const DecorPiece(sprite: Sprites.treeRound, position: Offset(60, 90), width: 110, height: 130),
        const DecorPiece(sprite: Sprites.treeWillow, position: Offset(60, 650), width: 140, height: 140),
        const DecorPiece(sprite: Sprites.riverbankReeds, position: Offset(605, 60), width: 50, height: 85),
        const DecorPiece(sprite: Sprites.riverbankRocks, position: Offset(830, 250), width: 75, height: 55),
        const DecorPiece(sprite: Sprites.riverbankPost, position: Offset(605, 640), width: 38, height: 60),
        const DecorPiece(sprite: Sprites.riverbankDriftwood, position: Offset(1445, 350), width: 85, height: 65),
        const DecorPiece(sprite: Sprites.riverbankReeds, position: Offset(1665, 640), width: 50, height: 85),
        const DecorPiece(sprite: Sprites.plantWildflowers, position: Offset(1060, 640), width: 80, height: 80),
        const DecorPiece(sprite: Sprites.plantFlowerbush, position: Offset(1060, 110), width: 80, height: 70),
        const DecorPiece(sprite: Sprites.treeLayered, position: Offset(2230, 110), width: 145, height: 170),
        const DecorPiece(sprite: Sprites.treeFruit, position: Offset(2230, 630), width: 145, height: 170),
      ],
      obstacles: const [
        ObstacleSpec(sprite: Sprites.obstacleFence, position: Offset(1000, 260), radius: 34),
        ObstacleSpec(sprite: Sprites.obstacleFence, position: Offset(1000, 470), radius: 34),
        ObstacleSpec(sprite: Sprites.obstacleRock, position: Offset(1150, 610), radius: 30),
        ObstacleSpec(sprite: Sprites.obstacleStump, position: Offset(1900, 260), radius: 30),
        ObstacleSpec(sprite: Sprites.obstacleBush, position: Offset(1980, 500), radius: 32),
      ],
      nests: const [
        NestSpec(sprite: Sprites.nestPlain, position: Offset(430, 400)),
        NestSpec(sprite: Sprites.nestRoped, position: Offset(1060, 380), rewardMultiplier: 1.2),
        NestSpec(sprite: Sprites.nestFloral, position: Offset(1720, 200), rewardMultiplier: 1.3),
        NestSpec(sprite: Sprites.nestWheat, position: Offset(2080, 560), rewardMultiplier: 1.3),
      ],
    ),
  ),
  ZoneDef(
    id: 'lake_shore',
    index: 3,
    name: 'Lake Shore',
    description: 'Islands, currents and the legendary golden nest await.',
    vistaSprite: Sprites.lakeVista,
    roundSeconds: 95,
    maxEggsStart: 2,
    maxEggsLate: 4,
    goal1Star: 2,
    goal2Star: 4,
    goal3Star: 6,
    layout: ZoneLayout(
      worldWidth: 2600,
      worldHeight: 720,
      chickenStart: const Offset(260, 400),
      spawnPoints: const [
        EggSpawnPoint(Offset(210, 320)),
        EggSpawnPoint(Offset(230, 480)),
        EggSpawnPoint(Offset(260, 620)),
      ],
      waterBodies: const [
        WaterBody(rect: Rect.fromLTWH(1350, 40, 1220, 640), flow: Offset(18, 10), isLake: true),
      ],
      bridges: const [
        BridgeSpec(
          sprite: Sprites.bridgeArched,
          position: Offset(1420, 400),
          width: 200,
          height: 160,
          safeRect: Rect.fromLTWH(1330, 335, 190, 130),
        ),
      ],
      islands: const [
        IslandSpec(
          sprite: Sprites.islandSmall,
          position: Offset(1720, 190),
          width: 230,
          height: 150,
          safeRect: Rect.fromLTWH(1620, 130, 200, 120),
        ),
        IslandSpec(
          sprite: Sprites.islandMedium,
          position: Offset(2020, 470),
          width: 270,
          height: 170,
          safeRect: Rect.fromLTWH(1905, 405, 230, 130),
        ),
        IslandSpec(
          sprite: Sprites.islandLarge,
          position: Offset(2350, 220),
          width: 300,
          height: 190,
          safeRect: Rect.fromLTWH(2220, 145, 260, 150),
        ),
      ],
      decor: [
        const DecorPiece(sprite: Sprites.coop, position: Offset(150, 210), width: 195, height: 175),
        const DecorPiece(sprite: Sprites.gate, position: Offset(130, 570), width: 150, height: 105),
        const DecorPiece(sprite: Sprites.treeRound, position: Offset(60, 100), width: 110, height: 130),
        const DecorPiece(sprite: Sprites.treeWillow, position: Offset(60, 660), width: 140, height: 140),
        const DecorPiece(sprite: Sprites.riverbankRocks, position: Offset(1300, 130), width: 80, height: 60),
        const DecorPiece(sprite: Sprites.riverbankReeds, position: Offset(1300, 630), width: 55, height: 90),
        const DecorPiece(sprite: Sprites.plantWildflowers, position: Offset(700, 630), width: 85, height: 85),
        const DecorPiece(sprite: Sprites.plantFlowerbush, position: Offset(700, 120), width: 85, height: 75),
        const DecorPiece(sprite: Sprites.plantGrass, position: Offset(1000, 640), width: 65, height: 85),
      ],
      obstacles: const [
        ObstacleSpec(sprite: Sprites.obstacleRock, position: Offset(560, 230), radius: 32),
        ObstacleSpec(sprite: Sprites.obstacleBush, position: Offset(640, 570), radius: 33),
        ObstacleSpec(sprite: Sprites.obstacleStump, position: Offset(950, 280), radius: 30),
        ObstacleSpec(sprite: Sprites.obstacleFence, position: Offset(1000, 550), radius: 34),
      ],
      nests: const [
        NestSpec(sprite: Sprites.nestPlain, position: Offset(500, 400)),
        NestSpec(sprite: Sprites.nestFloral, position: Offset(1720, 210), rewardMultiplier: 1.3),
        NestSpec(sprite: Sprites.nestWheat, position: Offset(2020, 490), rewardMultiplier: 1.35),
        NestSpec(
          sprite: Sprites.nestGolden,
          position: Offset(2350, 240),
          rewardMultiplier: 2.0,
          isRareGolden: true,
        ),
      ],
    ),
  ),
];
