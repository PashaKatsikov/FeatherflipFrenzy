import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../models/chicken_skin.dart';
import '../state/app_state.dart';
import '../widgets/coin_badge.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/ff_button.dart';
import '../widgets/menu_background.dart';

class ChickenSelectScreen extends StatelessWidget {
  const ChickenSelectScreen({super.key});

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
                Text('Chickens', style: FFText.title(size: 26)),
                const Spacer(),
                CoinBadge(amount: appState.coins),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900 ? 5 : 4;
                  return GridView.builder(
                    itemCount: kChickenSkins.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.86,
                    ),
                    itemBuilder: (context, index) {
                      final skin = kChickenSkins[index];
                      final owned = appState.ownsSkin(skin.id);
                      final selected = appState.selectedSkinId == skin.id;
                      return _SkinCard(skin: skin, owned: owned, selected: selected, appState: appState);
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

class _SkinCard extends StatelessWidget {
  final ChickenSkin skin;
  final bool owned;
  final bool selected;
  final AppState appState;
  const _SkinCard({required this.skin, required this.owned, required this.selected, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? FFColors.gold : const Color(0xFFD9A971), width: selected ? 3 : 2),
      ),
      child: Column(
        children: [
          Expanded(child: Image.asset(skin.sprite, fit: BoxFit.contain)),
          const SizedBox(height: 6),
          Text(skin.name, style: FFText.body(size: 13, color: Colors.white), textAlign: TextAlign.center, maxLines: 1),
          const SizedBox(height: 8),
          if (selected)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(color: FFColors.gold, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.check_rounded, color: FFColors.textDark, size: 20),
            )
          else
            FFButton(
              label: owned ? 'Select' : '${skin.price}',
              icon: owned ? null : Icons.monetization_on_rounded,
              style: owned ? FFButtonStyle.blue : FFButtonStyle.green,
              width: double.infinity,
              height: 38,
              fontSize: 13,
              onPressed: () {
                if (owned) {
                  appState.selectSkin(skin.id);
                  AudioService.instance.playSfx(Sfx.elementSelect);
                } else if (appState.buySkin(skin)) {
                  appState.selectSkin(skin.id);
                  AudioService.instance.playSfx(Sfx.rewardCollect);
                  Haptics.instance.medium();
                } else {
                  AudioService.instance.playSfx(Sfx.buttonTap);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You need ${skin.price - appState.coins} more coins for ${skin.name}.'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
