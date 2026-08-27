import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../models/upgrade.dart';
import '../state/app_state.dart';
import '../widgets/coin_badge.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/ff_button.dart';
import '../widgets/menu_background.dart';

class UpgradesScreen extends StatelessWidget {
  const UpgradesScreen({super.key});

  static const _icons = {
    UpgradeType.dashSpeed: Icons.speed_rounded,
    UpgradeType.dashRange: Icons.social_distance_rounded,
    UpgradeType.hitPower: Icons.bolt_rounded,
    UpgradeType.eggControl: Icons.control_camera_rounded,
    UpgradeType.rescueCharges: Icons.health_and_safety_rounded,
  };

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
                Text('Upgrades', style: FFText.title(size: 26)),
                const Spacer(),
                CoinBadge(amount: appState.coins),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: kUpgradeDefs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final def = kUpgradeDefs.values.elementAt(index);
                  final level = appState.upgradeLevel(def.type);
                  final maxed = level >= def.maxLevel;
                  final cost = def.costForLevel(level);
                  final canAfford = !maxed && appState.coins >= cost;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD9A971), width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: FFColors.warmYellow, borderRadius: BorderRadius.circular(14)),
                          child: Icon(_icons[def.type], color: FFColors.textDark, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(def.name, style: FFText.heading(size: 17)),
                              const SizedBox(height: 3),
                              Text(def.description, style: FFText.body(size: 12, color: Colors.white70)),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: level / def.maxLevel,
                                  minHeight: 8,
                                  backgroundColor: Colors.black26,
                                  color: FFColors.lightGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Level $level / ${def.maxLevel}', style: FFText.body(size: 11, color: Colors.white60)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 118,
                          child: FFButton(
                            label: maxed ? 'MAX' : '$cost',
                            icon: maxed ? null : Icons.monetization_on_rounded,
                            style: maxed ? FFButtonStyle.brown : FFButtonStyle.green,
                            width: 118,
                            height: 46,
                            fontSize: 15,
                            onPressed: maxed || !canAfford
                                ? null
                                : () {
                                    context.read<AppState>().purchaseUpgrade(def.type);
                                    AudioService.instance.playSfx(Sfx.rewardCollect);
                                    Haptics.instance.medium();
                                  },
                          ),
                        ),
                      ],
                    ),
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
