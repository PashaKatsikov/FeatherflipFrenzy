import 'package:flutter/services.dart';

/// Orientation policy for the whole game, kept in one place so iPhone and iPad
/// behave identically: the loading screen may be held either way, everything
/// after it is landscape-only.
class GameOrientation {
  GameOrientation._();

  static const List<DeviceOrientation> _loading = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const List<DeviceOrientation> _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static bool _lockedToLandscape = false;

  static Future<void> allowLoadingOrientations() {
    _lockedToLandscape = false;
    return SystemChrome.setPreferredOrientations(_loading);
  }

  static Future<void> lockLandscape() {
    _lockedToLandscape = true;
    return SystemChrome.setPreferredOrientations(_landscape);
  }

  /// Re-applies the landscape lock after the app returns to the foreground,
  /// since a scene restored by the system can come back rotated.
  static Future<void> reapplyIfLocked() {
    if (!_lockedToLandscape) return Future.value();
    return SystemChrome.setPreferredOrientations(_landscape);
  }
}
