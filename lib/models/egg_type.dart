import '../core/assets.dart';

/// The four egg variants described in the game design: each has a distinct
/// physics feel and a distinct coin reward.
enum EggType { normal, heavy, bouncy, gold }

extension EggTypeData on EggType {
  String get sprite => switch (this) {
        EggType.normal => Sprites.eggNormal,
        EggType.heavy => Sprites.eggHeavy,
        EggType.bouncy => Sprites.eggBouncy,
        EggType.gold => Sprites.eggGold,
      };

  String get label => switch (this) {
        EggType.normal => 'Egg',
        EggType.heavy => 'Heavy Egg',
        EggType.bouncy => 'Bouncy Egg',
        EggType.gold => 'Golden Egg',
      };

  /// Base coin reward for a successful delivery.
  int get baseReward => switch (this) {
        EggType.normal => 10,
        EggType.heavy => 15,
        EggType.bouncy => 18,
        EggType.gold => 30,
      };

  /// How much of the chicken's impulse actually transfers into the egg.
  /// Heavy eggs need much stronger hits.
  double get impulseTransfer => switch (this) {
        EggType.normal => 1.0,
        EggType.heavy => 0.62,
        EggType.bouncy => 1.05,
        EggType.gold => 0.95,
      };

  /// Ground friction (fraction of speed lost per second).
  double get friction => switch (this) {
        EggType.normal => 0.9,
        EggType.heavy => 1.35,
        EggType.bouncy => 0.55,
        EggType.gold => 0.85,
      };

  /// Restitution used when bouncing off obstacles / banks.
  double get bounciness => switch (this) {
        EggType.normal => 0.35,
        EggType.heavy => 0.15,
        EggType.bouncy => 0.85,
        EggType.gold => 0.4,
      };

  double get radius => switch (this) {
        EggType.normal => 17,
        EggType.heavy => 19,
        EggType.bouncy => 17,
        EggType.gold => 18,
      };

  /// Golden eggs disappear if not delivered in time.
  double? get lifespanSeconds => this == EggType.gold ? 12 : null;
}
