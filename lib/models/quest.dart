enum QuestMetric { eggsDelivered, coinsCollected, rescueDashUses, goldenEggsDelivered, roundsCompleted, bestStreakEver, cleanFlips }

enum QuestCategory { daily, achievement }

class QuestDef {
  final String id;
  final QuestCategory category;
  final String title;
  final QuestMetric metric;
  final int target;
  final int reward;

  const QuestDef({
    required this.id,
    required this.category,
    required this.title,
    required this.metric,
    required this.target,
    required this.reward,
  });
}

const List<QuestDef> kDailyQuestPool = [
  QuestDef(id: 'd_deliver_10', category: QuestCategory.daily, title: 'Deliver 10 eggs', metric: QuestMetric.eggsDelivered, target: 10, reward: 150),
  QuestDef(id: 'd_coins_500', category: QuestCategory.daily, title: 'Collect 500 coins', metric: QuestMetric.coinsCollected, target: 500, reward: 200),
  QuestDef(id: 'd_rescue_3', category: QuestCategory.daily, title: 'Use Rescue Dash 3 times', metric: QuestMetric.rescueDashUses, target: 3, reward: 150),
  QuestDef(id: 'd_golden_3', category: QuestCategory.daily, title: 'Deliver 3 golden eggs', metric: QuestMetric.goldenEggsDelivered, target: 3, reward: 250),
  QuestDef(id: 'd_rounds_3', category: QuestCategory.daily, title: 'Complete 3 rounds', metric: QuestMetric.roundsCompleted, target: 3, reward: 180),
  QuestDef(id: 'd_clean_8', category: QuestCategory.daily, title: 'Land 8 Clean Flips', metric: QuestMetric.cleanFlips, target: 8, reward: 180),
];

const List<QuestDef> kAchievements = [
  QuestDef(id: 'a_deliver_50', category: QuestCategory.achievement, title: 'Deliver 50 eggs in total', metric: QuestMetric.eggsDelivered, target: 50, reward: 300),
  QuestDef(id: 'a_deliver_250', category: QuestCategory.achievement, title: 'Deliver 250 eggs in total', metric: QuestMetric.eggsDelivered, target: 250, reward: 900),
  QuestDef(id: 'a_coins_2000', category: QuestCategory.achievement, title: 'Earn 2000 coins in total', metric: QuestMetric.coinsCollected, target: 2000, reward: 400),
  QuestDef(id: 'a_streak_8', category: QuestCategory.achievement, title: 'Reach an 8x Feather Streak', metric: QuestMetric.bestStreakEver, target: 8, reward: 500),
  QuestDef(id: 'a_golden_20', category: QuestCategory.achievement, title: 'Deliver 20 golden eggs', metric: QuestMetric.goldenEggsDelivered, target: 20, reward: 700),
  QuestDef(id: 'a_clean_40', category: QuestCategory.achievement, title: 'Land 40 Clean Flips', metric: QuestMetric.cleanFlips, target: 40, reward: 500),
];
