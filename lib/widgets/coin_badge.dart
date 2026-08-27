import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/theme.dart';

class CoinBadge extends StatelessWidget {
  final int amount;
  final double fontSize;
  const CoinBadge({super.key, required this.amount, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FFColors.panelBrownDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9A971), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Sprites.coinIcon, width: fontSize + 8, height: fontSize + 8),
          const SizedBox(width: 8),
          Text('$amount', style: FFText.stat(size: fontSize)),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final int maxStars;
  final double size;
  const StarRow({super.key, required this.stars, this.maxStars = 3, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (i) {
        final filled = i < stars;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: filled ? FFColors.gold : Colors.white54,
          size: size,
        );
      }),
    );
  }
}
