enum UpgradeType { dashSpeed, dashRange, hitPower, eggControl, rescueCharges }

class UpgradeDef {
  final UpgradeType type;
  final String name;
  final String description;
  final int maxLevel;
  final int baseCost;
  final double costGrowth;

  /// Maximum bonus fraction granted at max level (e.g. 0.30 == +30%).
  final double maxBonusFraction;

  const UpgradeDef({
    required this.type,
    required this.name,
    required this.description,
    required this.maxLevel,
    required this.baseCost,
    required this.costGrowth,
    required this.maxBonusFraction,
  });

  int costForLevel(int currentLevel) {
    if (currentLevel >= maxLevel) return -1;
    return (baseCost * (costGrowth * currentLevel + 1)).round();
  }

  /// Bonus fraction applied on top of the base stat at [level].
  double bonusAtLevel(int level) {
    if (maxLevel <= 1) return 0;
    return maxBonusFraction * (level / maxLevel);
  }
}

const Map<UpgradeType, UpgradeDef> kUpgradeDefs = {
  UpgradeType.dashSpeed: UpgradeDef(
    type: UpgradeType.dashSpeed,
    name: 'Dash Speed',
    description: 'The chicken sprints faster during a Feather Flip.',
    maxLevel: 5,
    baseCost: 150,
    costGrowth: 0.9,
    maxBonusFraction: 0.30,
  ),
  UpgradeType.dashRange: UpgradeDef(
    type: UpgradeType.dashRange,
    name: 'Dash Range',
    description: 'Feather Flip dashes reach farther before slowing down.',
    maxLevel: 5,
    baseCost: 150,
    costGrowth: 0.9,
    maxBonusFraction: 0.25,
  ),
  UpgradeType.hitPower: UpgradeDef(
    type: UpgradeType.hitPower,
    name: 'Hit Power',
    description: 'Every Feather Flip hit sends the egg flying with more force.',
    maxLevel: 5,
    baseCost: 180,
    costGrowth: 0.95,
    maxBonusFraction: 0.30,
  ),
  UpgradeType.eggControl: UpgradeDef(
    type: UpgradeType.eggControl,
    name: 'Egg Control',
    description: 'Eggs keep their momentum longer and travel truer.',
    maxLevel: 5,
    baseCost: 150,
    costGrowth: 0.85,
    maxBonusFraction: 0.20,
  ),
  UpgradeType.rescueCharges: UpgradeDef(
    type: UpgradeType.rescueCharges,
    name: 'Rescue Dash',
    description: 'Carry extra Rescue Dash charges into every round.',
    maxLevel: 2,
    baseCost: 500,
    costGrowth: 1.2,
    maxBonusFraction: 1.0,
  ),
};
