import 'package:flutter/services.dart';

/// Central gate for haptic feedback so the "Vibration" setting actually
/// controls every buzz in the game.
class Haptics {
  Haptics._();
  static final Haptics instance = Haptics._();

  bool enabled = true;

  /// Gameplay can trigger hits several times per second; firing the platform
  /// channel that often is both wasteful and unpleasant to feel.
  static const Duration _minInterval = Duration(milliseconds: 72);
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void setEnabled(bool value) => enabled = value;

  bool get _allowed {
    if (!enabled) return false;
    final now = DateTime.now();
    if (now.difference(_last) < _minInterval) return false;
    _last = now;
    return true;
  }

  void light() {
    if (_allowed) HapticFeedback.lightImpact();
  }

  void medium() {
    if (_allowed) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (_allowed) HapticFeedback.heavyImpact();
  }
}
