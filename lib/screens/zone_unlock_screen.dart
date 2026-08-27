import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/assets.dart';
import '../core/theme.dart';
import '../models/round_result.dart';
import '../models/zone.dart';
import '../widgets/ff_button.dart';
import '../widgets/menu_background.dart';
import 'round_results_screen.dart';

class ZoneUnlockScreen extends StatefulWidget {
  final ZoneDef zone;
  final RoundResult result;
  const ZoneUnlockScreen({super.key, required this.zone, required this.result});

  @override
  State<ZoneUnlockScreen> createState() => _ZoneUnlockScreenState();
}

class _ZoneUnlockScreenState extends State<ZoneUnlockScreen> {
  @override
  void initState() {
    super.initState();
    AudioService.instance.playSfx(Sfx.newZoneUnlock);
  }

  @override
  Widget build(BuildContext context) {
    return MenuBackground(
      vista: widget.zone.vistaSprite,
      darken: 0.15,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: FFColors.gold, width: 3),
                boxShadow: [BoxShadow(color: FFColors.gold.withValues(alpha: 0.5), blurRadius: 26, spreadRadius: 2)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: FFColors.gold, borderRadius: BorderRadius.circular(16)),
                    child: Text('NEW ZONE UNLOCKED!', style: FFText.heading(size: 18, color: FFColors.textDark)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 2.9,
                      child: Image.asset(widget.zone.vistaSprite, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.zone.name, style: FFText.title(size: 24), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(widget.zone.description, textAlign: TextAlign.center, style: FFText.body(size: 14, color: Colors.white70)),
                  const SizedBox(height: 18),
                  FFButton(
                    label: 'Great!',
                    style: FFButtonStyle.gold,
                    width: 220,
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => RoundResultsScreen(result: widget.result)),
                      );
                    },
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
