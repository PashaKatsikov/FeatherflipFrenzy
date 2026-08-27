import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shared full-bleed background used by every menu-style screen: a vista
/// illustration blended into the game's sky/green gradient so it always
/// covers irregular screen aspect ratios (iPhone notches, iPad, etc.)
/// without visible seams.
class MenuBackground extends StatelessWidget {
  final String vista;
  final Widget child;
  final double darken;

  const MenuBackground({super.key, required this.vista, required this.child, this.darken = 0.25});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: FFColors.skyGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(vista, fit: BoxFit.cover, alignment: Alignment.center),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: darken)),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}
