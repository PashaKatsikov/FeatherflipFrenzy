import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/menu_background.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                Text('Settings', style: FFText.title(size: 26)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 480,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFD9A971), width: 3),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _ToggleRow(
                            icon: Icons.volume_up_rounded,
                            label: 'Sound Effects',
                            value: appState.sfxOn,
                            onChanged: (v) {
                              appState.setSfxOn(v);
                              AudioService.instance.setSfxEnabled(v);
                              if (v) AudioService.instance.playSfx(Sfx.buttonTap);
                            },
                          ),
                          _ToggleRow(
                            icon: Icons.vibration_rounded,
                            label: 'Vibration',
                            value: appState.vibrationOn,
                            onChanged: (v) {
                              appState.setVibrationOn(v);
                              Haptics.instance.setEnabled(v);
                              if (v) Haptics.instance.light();
                            },
                          ),
                          _ToggleRow(
                            icon: Icons.hd_rounded,
                            label: 'Extra Visual Effects',
                            value: appState.highGraphics,
                            onChanged: appState.setHighGraphics,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(color: Colors.white24, height: 1),
                          ),
                          _LinkRow(
                            icon: Icons.privacy_tip_rounded,
                            label: 'Privacy Policy',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FFWebViewScreen(title: 'Privacy Policy', url: AppLinks.privacyPolicy),
                              ),
                            ),
                          ),
                          _LinkRow(
                            icon: Icons.support_agent_rounded,
                            label: 'Support',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FFWebViewScreen(title: 'Support', url: AppLinks.support),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text('Featherflip Frenzy v1.0.0', style: FFText.body(size: 12, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: FFColors.warmYellow, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: FFText.body(size: 16, color: Colors.white))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FFColors.gold,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        AudioService.instance.playSfx(Sfx.buttonTap);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: FFText.body(size: 16, color: Colors.white))),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
