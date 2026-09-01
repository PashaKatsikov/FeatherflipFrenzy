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
  static const String _pendingAtKey = 'ff.coop.vault.hold.at';

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

  /// A tapped push URL is held apart from the config vault so a push never
  /// becomes the destination of a later organic launch.
  Future<void> stashPushUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      final existing = (await _secure.read(key: _pendingUrlKey))?.trim();
      await _secure.write(key: _pendingUrlKey, value: trimmed);
      if (existing != trimmed || _preferences.getInt(_pendingAtKey) == null) {
        await _preferences.setInt(
          _pendingAtKey,
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }
    } catch (_) {}
  }

  /// Survives a kill between the tap and the first WebView frame, without
  /// touching the cached config URL.
  Future<void> persistPushDestination(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    await stashPushUrl(trimmed);
    await saveRoute(FlipRoute.web);
  }

  /// A tap that never reached the WebView stays valid only briefly; after
  /// that the config decides again.
  bool get _pendingExpired {
    final stamp = _preferences.getInt(_pendingAtKey);
    if (stamp == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - stamp;
    return age < 0 || age > FlipGateConfig.pushHoldSeconds;
  }

  Future<String?> peekPushUrl() async {
    try {
      final trimmed = (await _secure.read(key: _pendingUrlKey))?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      if (_pendingExpired) {
        await clearPushUrl();
        return null;
      }
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<String?> consumePushUrl() async {
    final value = await peekPushUrl();
    await clearPushUrl();
    return value;
  }

  Future<void> clearPushUrl() async {
    try {
      await _secure.delete(key: _pendingUrlKey);
    } catch (_) {}
    await _preferences.remove(_pendingAtKey);
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
