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

enum _ShopTab { skins, gift }

/// Everything here is paid for with coins earned by playing: the game ships
/// without in-app purchases, so no real-money pricing is shown anywhere.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  _ShopTab _tab = _ShopTab.skins;

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
                Text('Shop', style: FFText.title(size: 26)),
                const Spacer(),
                CoinBadge(amount: appState.coins),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Tab(
                  label: 'Chicken Skins',
                  selected: _tab == _ShopTab.skins,
                  onTap: () => setState(() => _tab = _ShopTab.skins),
                ),
                const SizedBox(width: 10),
                _Tab(
                  label: 'Daily Gift',
                  selected: _tab == _ShopTab.gift,
                  badge: appState.dailyGiftAvailable,
                  onTap: () => setState(() => _tab = _ShopTab.gift),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tab == _ShopTab.skins ? _buildSkins(appState) : _buildGift(appState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkins(AppState appState) {
    final skins = kChickenSkins.where((s) => s.price > 0).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : 3;
        return GridView.builder(
          itemCount: skins.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final skin = skins[index];
            final owned = appState.ownsSkin(skin.id);
            final affordable = appState.coins >= skin.price;
            return _ShopCard(
              icon: skin.sprite,
              title: skin.name,
              subtitle: owned ? 'Unlocked' : 'Chicken skin',
              price: '${skin.price}',
              owned: owned,
              enabled: affordable,
              onBuy: () {
                if (appState.buySkin(skin)) {
                  AudioService.instance.playSfx(Sfx.rewardCollect);
                  Haptics.instance.medium();
                  _showToast('${skin.name} unlocked!');
                } else {
                  AudioService.instance.playSfx(Sfx.buttonTap);
                  _showToast('Not enough coins yet.');
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGift(AppState appState) {
    final available = appState.dailyGiftAvailable;
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A5A34), FFColors.panelBrown],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD9A971), width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(Sprites.coinGoldIcon, width: 84, height: 84),
                const SizedBox(height: 12),
                Text('Daily Farm Gift', style: FFText.heading(size: 20)),
                const SizedBox(height: 8),
                Text(
                  available
                      ? 'Collect ${AppState.dailyGiftAmount} free coins. A fresh gift is ready every day.'
                      : 'Already collected today. Come back tomorrow for another gift!',
                  textAlign: TextAlign.center,
                  style: FFText.body(size: 14, color: Colors.white70),
                ),
                const SizedBox(height: 18),
                FFButton(
                  label: available ? 'Collect +${AppState.dailyGiftAmount}' : 'Collected',
                  style: available ? FFButtonStyle.gold : FFButtonStyle.brown,
                  width: 240,
                  icon: available ? Icons.card_giftcard_rounded : Icons.check_rounded,
                  onPressed: available
                      ? () {
                          if (appState.claimDailyGift()) {
                            AudioService.instance.playSfx(Sfx.rewardCollect);
                            Haptics.instance.medium();
                            _showToast('+${AppState.dailyGiftAmount} coins collected!');
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap, this.badge = false});

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: FFText.body(size: 14, color: selected ? FFColors.textDark : Colors.white)),
            if (badge) ...[
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(color: Color(0xFFE8503A), shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String price;
  final bool owned;
  final bool enabled;
  final VoidCallback onBuy;
  const _ShopCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onBuy,
    this.owned = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8A5A34), FFColors.panelBrown],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9A971), width: 2),
      ),
      child: Column(
        children: [
          Expanded(child: Image.asset(icon, fit: BoxFit.contain)),
          Text(title, style: FFText.body(size: 13, color: Colors.white), textAlign: TextAlign.center, maxLines: 1),
          Text(subtitle, style: FFText.body(size: 10, color: Colors.white60), textAlign: TextAlign.center, maxLines: 1),
          const SizedBox(height: 6),
          FFButton(
            label: owned ? 'Owned' : price,
            icon: owned ? Icons.check_rounded : Icons.monetization_on_rounded,
            style: owned ? FFButtonStyle.brown : (enabled ? FFButtonStyle.gold : FFButtonStyle.brown),
            width: double.infinity,
            height: 36,
            fontSize: 12,
            onPressed: owned ? null : onBuy,
          ),
        ],
      ),
    );
  }
}
