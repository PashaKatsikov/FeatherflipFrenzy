import 'zone.dart';

enum YardChallengeKind { heavyHarvest, goldenHour, shortShift }

/// One daily special on a single farm zone. The kind and zone are rolled
/// from the calendar date so they stay stable if the app is relaunched.
class YardChallenge {
  final YardChallengeKind kind;
  final String zoneId;

  const YardChallenge({required this.kind, required this.zoneId});

  ZoneDef get zone => kZones.firstWhere((z) => z.id == zoneId, orElse: () => kZones.first);

  String get title => switch (kind) {
        YardChallengeKind.heavyHarvest => 'Heavy Harvest',
        YardChallengeKind.goldenHour => 'Golden Hour',
        YardChallengeKind.shortShift => 'Short Shift',
      };

  String get description => switch (kind) {
        YardChallengeKind.heavyHarvest => 'More heavy eggs, and deliveries pay 30% extra.',
        YardChallengeKind.goldenHour => 'Golden eggs turn up far more often.',
        YardChallengeKind.shortShift => 'A quicker round with gentler star goals.',
      };

  static YardChallengeKind? kindFromName(String name) {
    for (final kind in YardChallengeKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

class YardChallengeRules {
  static const int completionBonus = 100;
  static const double heavyHarvestCoinMultiplier = 1.3;
  static const int shortShiftSecondsDelta = -15;
  static const int shortShiftGoalRelief = 1;
}
