import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/theme.dart';
import '../models/yard_challenge.dart';
import '../models/zone.dart';
import '../state/app_state.dart';
import '../widgets/coin_badge.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/menu_background.dart';
import 'game_screen.dart';

class ZoneSelectScreen extends StatefulWidget {
  const ZoneSelectScreen({super.key});

  @override
  State<ZoneSelectScreen> createState() => _ZoneSelectScreenState();
}

class _ZoneSelectScreenState extends State<ZoneSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshDailyState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
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
                Text('Select Zone', style: FFText.title(size: 26)),
                const Spacer(),
                CoinBadge(amount: appState.coins),
              ],
            ),
            const SizedBox(height: 12),
            if (appState.todaysChallenge != null)
              _DailyChallengeBanner(challenge: appState.todaysChallenge!, claimed: !appState.dailyChallengeRewardAvailable),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  for (final zone in kZones)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _ZoneCard(
                          zone: zone,
                          unlocked: appState.isZoneUnlocked(zone.index),
                          stars: appState.starsFor(zone.id),
                          isTodaysChallenge: appState.todaysChallenge?.zoneId == zone.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final ZoneDef zone;
  final bool unlocked;
  final int stars;
  final bool isTodaysChallenge;
  const _ZoneCard({required this.zone, required this.unlocked, required this.stars, this.isTodaysChallenge = false});

  int get unlockRequirement => zone.index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!unlocked) {
          AudioService.instance.playSfx(Sfx.buttonTap);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Earn a star in zone $unlockRequirement to open ${zone.name}.'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        AudioService.instance.playSfx(Sfx.elementSelect);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(zone: zone, challenge: context.read<AppState>().challengeFor(zone))));
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), offset: const Offset(0, 4), blurRadius: 8)],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD9A971), width: 3),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(zone.vistaSprite, fit: BoxFit.cover),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: unlocked ? 0.55 : 0.75)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1],
                      ),
                    ),
                  ),
                ),
                if (!unlocked)
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x66000000)),
                  ),
                if (isTodaysChallenge)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FFColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text("TODAY'S YARD", style: FFText.body(size: 10, color: FFColors.textDark)),
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${zone.index + 1}. ${zone.name}',
                        style: FFText.heading(size: 15),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      unlocked
                          ? StarRow(stars: stars, size: 18)
                          : Row(
                              children: [
                                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Text('Locked', style: FFText.body(size: 12, color: Colors.white70)),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyChallengeBanner extends StatelessWidget {
  final YardChallenge challenge;
  final bool claimed;
  const _DailyChallengeBanner({required this.challenge, required this.claimed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FFColors.gold.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9A971), width: 2),
      ),
      child: Row(
        children: [
          Icon(claimed ? Icons.check_circle_rounded : Icons.wb_sunny_rounded, color: FFColors.textDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Yard: ${challenge.zone.name} — ${challenge.title}",
                  style: FFText.heading(size: 14, color: FFColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  claimed
                      ? 'Bonus collected. Play again for the extra rules!'
                      : '${challenge.description} Finish a round for +${YardChallengeRules.completionBonus} coins.',
                  style: FFText.body(size: 11, color: FFColors.textDark.withValues(alpha: 0.75)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
