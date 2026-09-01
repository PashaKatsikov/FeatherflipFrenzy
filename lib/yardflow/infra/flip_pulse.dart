import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'flip_tap_bridge.dart';
import 'flip_trace.dart';
import 'yard_locker.dart';

/// Delivery is not a tap: routing here would hijack the next organic launch.
@pragma('vm:entry-point')
Future<void> flipBackgroundMessage(RemoteMessage _) async {}

class FlipPulse {
  FlipPulse(this._locker, {required this.enabled});

  final YardLocker _locker;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<void>? _launchFuture;
  Future<bool>? _permissionFuture;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String url)? onOrphanDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> captureLaunchTap() => _launchFuture ??= _captureLaunchTap();

  Future<void> persistAndDeliver(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      await _locker.persistPushDestination(trimmed);
    } catch (_) {}
    final live = onDestination;
    if (live != null) {
      live(trimmed);
      return;
    }
    onOrphanDestination?.call(trimmed);
  }

  Future<String?> takePushUrl() async {
    final fromBridge = await _readBridge();
    final fromLocker = await _locker.peekPushUrl();
    final url = _firstHttpUrl(<String?>[fromBridge, fromLocker]);
    if (url == null) return null;
    await _locker.persistPushDestination(url);
    return url;
  }

  Future<String?> _readBridge() async {
    try {
      final first = await FlipTapBridge.consume();
      if (first != null) return first;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 48));
    try {
      return await FlipTapBridge.consume();
    } catch (_) {
      return null;
    }
  }

  static String? _firstHttpUrl(List<String?> candidates) {
    for (final value in candidates) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      final uri = Uri.tryParse(trimmed);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Future<void> _captureLaunchTap() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final url = urlFrom(message);
      if (url == null) return;
      flipTrace(() => '[FF.COOP] opened-app url=$url');
      unawaited(persistAndDeliver(url));
    });
    try {
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      final initialUrl = initial == null ? null : urlFrom(initial);
      if (initialUrl != null) {
        flipTrace(() => '[FF.COOP] initial url=$initialUrl');
        await persistAndDeliver(initialUrl);
      }
    } catch (_) {}
  }

  Future<void> _boot() async {
    if (!enabled) return;
    await captureLaunchTap();
    final messaging = _messaging ?? FirebaseMessaging.instance;
    _messaging = messaging;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    await _waitForApns();
    _token = await messaging.getToken();
  }

  static String? urlFrom(RemoteMessage message) => extract(message.data);

  static String? extract(Map<String, dynamic> payload) {
    const keys = <String>{
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
      'href',
      'redirect',
      'open_url',
      'web_url',
      'click_url',
    };

    bool looksLikeUrl(String value) {
      final uri = Uri.tryParse(value.trim());
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    }

    String? fromMap(Map<String, dynamic> map) {
      for (final entry in map.entries) {
        if (!keys.contains(entry.key.toString().toLowerCase())) continue;
        final value = entry.value;
        if (value is String) {
          final trimmed = value.trim();
          if (looksLikeUrl(trimmed)) return trimmed;
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              final found = fromMap(Map<String, dynamic>.from(decoded));
              if (found != null) return found;
            }
          } catch (_) {}
        }
      }
      for (final container in const <String>[
        'payload',
        'data',
        'fcm_options',
      ]) {
        final nested = map[container];
        if (nested is Map) {
          final found = fromMap(Map<String, dynamic>.from(nested));
          if (found != null) return found;
        }
        if (nested is String) {
          final trimmed = nested.trim();
          if (looksLikeUrl(trimmed)) return trimmed;
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              final found = fromMap(Map<String, dynamic>.from(decoded));
              if (found != null) return found;
            }
          } catch (_) {}
        }
      }
      return null;
    }

    return fromMap(payload);
  }

  Future<void> _waitForApns({int attempts = 8}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 615));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _locker.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _locker.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _locker.setPushAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _locker.markPushDeniedByOs();
    }
    if (accepted) {
      await _waitForApns(attempts: 11);
      _token = await _messaging!.getToken();
      if (_token?.isNotEmpty ?? false) onTokenChanged?.call(_token!);
    }
    return accepted;
  }
}
