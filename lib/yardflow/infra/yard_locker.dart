import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/flip_gate_config.dart';
import '../core/flip_models.dart';

class YardLocker {
  static const String _routeKey = 'ff.coop.lane';
  static const String _expiryKey = 'ff.coop.until';
  static const String _inviteKey = 'ff.coop.nudge.at';
  static const String _inviteSettledKey = 'ff.coop.nudge.done';
  static const String _permissionKey = 'ff.coop.bell.ok';
  static const String _osDeniedKey = 'ff.coop.bell.os';
  static const String _savedUrlKey = 'ff.coop.vault.href';
  static const String _pendingUrlKey = 'ff.coop.vault.hold';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  FlipRoute get route => FlipRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(FlipRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      final expiry = expiresAt ??
          DateTime.now()
                  .add(Duration(days: FlipGateConfig.savedUrlExpiryDays))
                  .millisecondsSinceEpoch ~/
              1000;
      await _preferences.setInt(_expiryKey, expiry);
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() =>
      _preferences.setBool(_osDeniedKey, true);

  bool get inviteSettled => _preferences.getBool(_inviteSettledKey) ?? false;

  Future<void> markInviteSettled() =>
      _preferences.setBool(_inviteSettledKey, true);

  bool get shouldShowPushInvite {
    if (inviteSettled || pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);
}
