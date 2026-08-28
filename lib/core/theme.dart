import 'dart:async';

import 'package:flutter/material.dart';

/// Premium-casual farmyard color palette, matching the painted art style of
/// the game's asset pack.
class FFColors {
  static const richGreen = Color(0xFF3E9E3B);
  static const lightGreen = Color(0xFF8FD657);
  static const skyBlue = Color(0xFF4FC3F7);
  static const turquoise = Color(0xFF2FD1C5);
  static const white = Color(0xFFFFFFFF);
  static const warmYellow = Color(0xFFFFC93C);
  static const gold = Color(0xFFFFB300);
  static const brown = Color(0xFF7A4A2B);
  static const combRed = Color(0xFFE94F3D);
  static const orange = Color(0xFFFF9642);
  static const beige = Color(0xFFF3E3C3);
  static const softBlue = Color(0xFF6FA8DC);
  static const naturalGray = Color(0xFF8C8C8C);

  static const panelBrown = Color(0xFF5C3A22);
  static const panelBrownDark = Color(0xFF412712);
  static const textDark = Color(0xFF3B2415);

  static const List<Color> skyGradient = [Color(0xFF6FCBF5), Color(0xFFBDEBFF)];
}

class FFText {
  static const _family = 'Roboto';

  static TextStyle title({double size = 34, Color color = FFColors.white}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: const [
          Shadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 4),
        ],
      );

  static TextStyle heading({double size = 22, Color color = FFColors.white}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body({double size = 16, Color color = FFColors.textDark}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle button({double size = 20, Color color = FFColors.white}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle stat({double size = 18, Color color = FFColors.white}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );
}

ThemeData buildFFTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Fredoka',
    scaffoldBackgroundColor: FFColors.richGreen,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FFColors.richGreen,
      brightness: Brightness.light,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// "Loading" with a cycling `.` / `..` / `...` suffix.
class LoadingDotsLabel extends StatefulWidget {
  const LoadingDotsLabel({super.key, required this.style});

  final TextStyle style;

  @override
  State<LoadingDotsLabel> createState() => _LoadingDotsLabelState();
}

class _LoadingDotsLabelState extends State<LoadingDotsLabel> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 355), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Loading${'.' * _step}', style: widget.style);
  }
}
