import 'package:flutter/material.dart';
import '../core/audio_service.dart';
import '../core/assets.dart';
import '../core/theme.dart';

enum FFButtonStyle { green, blue, red, gold, brown }

class FFButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final FFButtonStyle style;
  final IconData? icon;
  final double width;
  final double height;
  final double fontSize;

  const FFButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = FFButtonStyle.green,
    this.icon,
    this.width = 260,
    this.height = 58,
    this.fontSize = 20,
  });

  @override
  State<FFButton> createState() => _FFButtonState();
}

class _FFButtonState extends State<FFButton> {
  bool _pressed = false;

  List<Color> _colors() {
    switch (widget.style) {
      case FFButtonStyle.green:
        return const [Color(0xFF7ED957), Color(0xFF3E9E3B)];
      case FFButtonStyle.blue:
        return const [Color(0xFF6FC8F2), Color(0xFF2E8FCF)];
      case FFButtonStyle.red:
        return const [Color(0xFFF2725A), Color(0xFFD8402A)];
      case FFButtonStyle.gold:
        return const [FFColors.warmYellow, FFColors.gold];
      case FFButtonStyle.brown:
        return const [Color(0xFF9C6B44), Color(0xFF6E4527)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final colors = _colors();
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTap: disabled
          ? null
          : () {
              AudioService.instance.playSfx(Sfx.buttonTap);
              widget.onPressed!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 72),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: disabled ? const [Color(0xFFB9B9B9), Color(0xFF8C8C8C)] : colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: widget.fontSize + 4),
                const SizedBox(width: 8),
              ],
              // Narrow buttons (grid cards, quest rewards) must clip their
              // label rather than overflow the pill.
              Flexible(
                child: Text(
                  widget.label,
                  style: FFText.button(size: widget.fontSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
