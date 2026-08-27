import 'package:flutter/material.dart';
import '../core/audio_service.dart';
import '../core/assets.dart';
import '../core/theme.dart';

class FFBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const FFBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(Sfx.menuClose);
        onPressed();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: FFColors.panelBrownDark.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD9A971), width: 2),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
