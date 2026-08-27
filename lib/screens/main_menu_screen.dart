import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/coin_badge.dart';
import '../widgets/ff_button.dart';
import '../widgets/menu_background.dart';
import 'chicken_select_screen.dart';
import 'quests_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'upgrades_screen.dart';
import 'zone_select_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MenuBackground(
      vista: Sprites.pastureVista,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoinBadge(amount: appState.coins),
                const Spacer(),
                _IconCircleButton(
                  icon: Icons.settings_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Landscape heights vary a lot between an iPhone SE and an
                  // iPad, so the hero block scales instead of overflowing.
                  final available = constraints.maxHeight;
                  final playHeight = available < 300 ? 56.0 : 68.0;
                  final logoHeight = (available - playHeight - 40).clamp(70.0, 190.0);
                  final tileSpacing = available < 300 ? 10.0 : 14.0;
                  final tileAspect = available < 300 ? 1.8 : 1.35;
                  return Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(UiImages.logo, height: logoHeight, fit: BoxFit.contain),
                            SizedBox(height: available < 300 ? 12 : 22),
                            FFButton(
                              label: 'PLAY',
                              icon: Icons.play_arrow_rounded,
                              width: 260,
                              height: playHeight,
                              fontSize: 26,
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZoneSelectScreen()));
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: tileSpacing,
                            crossAxisSpacing: tileSpacing,
                            childAspectRatio: tileAspect,
                            children: [
                              _MenuTile(
                                label: 'Upgrades',
                                icon: Icons.bolt_rounded,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradesScreen())),
                              ),
                              _MenuTile(
                                label: 'Chickens',
                                icon: Icons.pets_rounded,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChickenSelectScreen())),
                              ),
                              _MenuTile(
                                label: 'Quests',
                                icon: Icons.flag_rounded,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuestsScreen())),
                              ),
                              _MenuTile(
                                label: 'Shop',
                                icon: Icons.storefront_rounded,
                                badge: appState.dailyGiftAvailable,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _MenuTile({required this.label, required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(Sfx.menuOpen);
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A5A34), FFColors.panelBrown],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9A971), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 3), blurRadius: 5)],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: FFColors.warmYellow, size: 28),
                  const SizedBox(height: 4),
                  Text(label, style: FFText.body(size: 14, color: Colors.white), maxLines: 1),
                ],
              ),
            ),
            if (badge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8503A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(Sfx.buttonTap);
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: FFColors.panelBrownDark.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD9A971), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
