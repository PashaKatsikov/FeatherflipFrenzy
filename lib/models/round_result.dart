import 'zone.dart';

class RoundResult {
  final ZoneDef zone;
  final int eggsDelivered;
  final int coinsEarned;
  final int bestStreak;
  final int stars;
  final bool unlockedNewZone;

  const RoundResult({
    required this.zone,
    required this.eggsDelivered,
    required this.coinsEarned,
    required this.bestStreak,
    required this.stars,
    required this.unlockedNewZone,
  });
}
