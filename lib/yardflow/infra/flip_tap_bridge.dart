import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class FlipTapBridge {
  static const String dartKey = 'ff_coop_link';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final value = preferences.getString(dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
