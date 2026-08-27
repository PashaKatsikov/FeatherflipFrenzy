import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../models/quest.dart';
import '../state/app_state.dart';
import '../widgets/coin_badge.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/ff_button.dart';
import '../widgets/menu_background.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  bool _daily = true;

  @override
  void initState() {
    super.initState();
    // Covers a session that crossed midnight without ever being backgrounded.
    context.read<AppState>().refreshDailyState();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final quests = _daily ? kDailyQuestPool : kAchievements;
    return MenuBackground(
      vista: Sprites.pastureVista,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FFBackButton(onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 16),
                Text('Quests', style: FFText.title(size: 26)),
                const Spacer(),
                CoinBadge(amount: appState.coins),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Tab(label: 'Daily', selected: _daily, onTap: () => setState(() => _daily = true)),
                const SizedBox(width: 10),
                _Tab(label: 'Achievements', selected: !_daily, onTap: () => setState(() => _daily = false)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: quests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final quest = quests[index];
                  final progress = _daily ? appState.dailyQuestProgress(quest) : appState.lifetimeMetric(quest.metric);
                  final claimed = _daily ? appState.dailyClaimed.contains(quest.id) : appState.achievementClaimed.contains(quest.id);
                  final claimable = _daily ? appState.isDailyClaimable(quest) : appState.isAchievementClaimable(quest);
                  return _QuestRow(
                    quest: quest,
                    progress: progress,
                    claimed: claimed,
                    claimable: claimable,
                    onClaim: () {
                      final ok = _daily ? appState.claimDailyQuest(quest) : appState.claimAchievement(quest);
                      if (ok) {
                        AudioService.instance.playSfx(Sfx.rewardCollect);
                        Haptics.instance.medium();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(Sfx.elementSelect);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? FFColors.warmYellow : FFColors.panelBrownDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD9A971), width: 2),
        ),
        child: Text(label, style: FFText.body(size: 14, color: selected ? FFColors.textDark : Colors.white)),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final QuestDef quest;
  final int progress;
  final bool claimed;
  final bool claimable;
  final VoidCallback onClaim;
  const _QuestRow({
    required this.quest,
    required this.progress,
    required this.claimed,
    required this.claimable,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress > quest.target ? quest.target : progress;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9A971), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest.title, style: FFText.heading(size: 15)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: clampedProgress / quest.target,
                    minHeight: 9,
                    backgroundColor: Colors.black26,
                    color: claimed ? FFColors.naturalGray : FFColors.lightGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text('$clampedProgress / ${quest.target}', style: FFText.body(size: 11, color: Colors.white60)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: FFButton(
              label: claimed ? 'Claimed' : '+${quest.reward}',
              icon: claimed ? Icons.check_rounded : Icons.monetization_on_rounded,
              style: claimed ? FFButtonStyle.brown : FFButtonStyle.gold,
              width: 110,
              height: 44,
              fontSize: 14,
              onPressed: claimable ? onClaim : null,
            ),
          ),
        ],
      ),
    );
  }
}
