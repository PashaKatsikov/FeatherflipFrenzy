import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../models/round_result.dart';
import '../state/app_state.dart';
import '../widgets/ff_button.dart';
import '../widgets/coin_badge.dart';
import '../widgets/menu_background.dart';
import 'game_screen.dart';
import 'main_menu_screen.dart';

class RoundResultsScreen extends StatefulWidget {
  final RoundResult result;
  const RoundResultsScreen({super.key, required this.result});

  @override
  State<RoundResultsScreen> createState() => _RoundResultsScreenState();
}

class _RoundResultsScreenState extends State<RoundResultsScreen> {
  bool _bonusClaimed = false;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playSfx(Sfx.roundComplete);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final success = result.stars > 0;
    // Earned purely by clearing every star goal - no ads, no purchases.
    final perfect = result.stars >= 3 && result.coinsEarned > 0;
    final perfectBonus = (result.coinsEarned * 0.5).round().clamp(1, 1 << 30);

    return MenuBackground(
      vista: result.zone.vistaSprite,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A5A34), FFColors.panelBrown],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFD9A971), width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(
                      color: success ? FFColors.gold : FFColors.naturalGray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      success ? 'ROUND COMPLETE!' : 'ROUND OVER',
                      style: FFText.heading(size: 20, color: FFColors.textDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StarRow(stars: result.stars, size: 32),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(icon: Sprites.eggNormal, label: 'Eggs', value: '${result.eggsDelivered}'),
                      _StatColumn(icon: Sprites.coinIcon, label: 'Coins', value: '${result.coinsEarned}'),
                      _StatColumn(
                        icon: null,
                        iconData: Icons.local_fire_department_rounded,
                        label: 'Best Streak',
                        value: '${result.bestStreak}',
                      ),
                    ],
                  ),
                  if (!success) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Deliver ${result.zone.goal1Star} eggs to earn your first star.',
                      textAlign: TextAlign.center,
                      style: FFText.body(size: 13, color: Colors.white70),
                    ),
                  ],
                  if (perfect) ...[
                    const SizedBox(height: 16),
                    FFButton(
                      label: _bonusClaimed ? 'Bonus Claimed' : 'Perfect Bonus +$perfectBonus',
                      style: FFButtonStyle.gold,
                      width: 280,
                      icon: _bonusClaimed ? Icons.check_rounded : Icons.emoji_events_rounded,
                      onPressed: _bonusClaimed
                          ? null
                          : () {
                              setState(() => _bonusClaimed = true);
                              context.read<AppState>().addCoins(perfectBonus);
                              AudioService.instance.playSfx(Sfx.rewardCollect);
                              Haptics.instance.medium();
                            },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FFButton(
                        label: 'Menu',
                        style: FFButtonStyle.brown,
                        width: 130,
                        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                          (route) => false,
                        ),
                      ),
                      FFButton(
                        label: 'Play Again',
                        style: FFButtonStyle.green,
                        width: 130,
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => GameScreen(zone: result.zone)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String? icon;
  final IconData? iconData;
  final String label;
  final String value;
  const _StatColumn({this.icon, this.iconData, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon != null
            ? Image.asset(icon!, width: 34, height: 34)
            : Icon(iconData, color: FFColors.warmYellow, size: 32),
        const SizedBox(height: 6),
        Text(value, style: FFText.heading(size: 20)),
        Text(label, style: FFText.body(size: 12, color: Colors.white70)),
      ],
    );
  }
}
