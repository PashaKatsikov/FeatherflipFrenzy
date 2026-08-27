import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppsFlyer wrapper that records install attribution (organic vs paid) and
/// a handful of in-game events. Failures are swallowed so analytics can
/// never block gameplay.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _devKey = 'XiXiK2CRj3ZvcrsKT6rwb5';
  static const _appId = '6802366515';
  static const _prefKey = 'ff_af_attribution_v1';

  AppsflyerSdk? _sdk;
  bool _started = false;

  /// `organic`, `non-organic`, or `unknown` until conversion data arrives.
  String attributionStatus = 'unknown';
  bool? isOrganic;
  String? mediaSource;
  String? campaign;

  bool get isNonOrganic => isOrganic == false;

  Future<void> prepare() async {
    await _restore();
    try {
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: _devKey,
          appId: _appId,
          showDebug: false,
          timeToWaitForATTUserAuthorization: 60,
          manualStart: true,
        ),
      );
      sdk.onInstallConversionData(_handleConversionData);
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: false,
      );
      _sdk = sdk;
    } catch (_) {}
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _requestTracking();
    try {
      _sdk?.startSDK();
    } catch (_) {}
    logEvent('game_open');
  }

  Future<void> _requestTracking() async {
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {}
  }

  void logEvent(String name, [Map<String, dynamic>? values]) {
    final payload = <String, dynamic>{
      'attribution': attributionStatus,
      if (isOrganic != null) 'is_organic': isOrganic,
      if (mediaSource != null) 'media_source': mediaSource,
      ...?values,
    };
    try {
      _sdk?.logEvent(name, payload);
    } catch (_) {}
  }

  void _handleConversionData(dynamic data) {
    try {
      final root = _asStringMap(data);
      if (root == null) return;
      var payload = root['payload'] ?? root;
      if (payload is String) {
        payload = jsonDecode(payload);
      }
      final map = _asStringMap(payload);
      if (map == null) return;

      final status = (map['af_status'] ?? map['afStatus'] ?? '').toString();
      final lower = status.toLowerCase();
      if (lower.contains('non')) {
        isOrganic = false;
        attributionStatus = 'non-organic';
      } else if (lower.contains('organic')) {
        isOrganic = true;
        attributionStatus = 'organic';
      }

      mediaSource = map['media_source']?.toString();
      campaign = map['campaign']?.toString();
      _persist();
      _sdk?.setAdditionalData({
        'user_type': attributionStatus,
        'is_organic': isOrganic == true ? 'true' : 'false',
      });
    } catch (_) {}
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      attributionStatus = json['attributionStatus'] as String? ?? attributionStatus;
      isOrganic = json['isOrganic'] as bool?;
      mediaSource = json['mediaSource'] as String?;
      campaign = json['campaign'] as String?;
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode({
          'attributionStatus': attributionStatus,
          'isOrganic': isOrganic,
          'mediaSource': mediaSource,
          'campaign': campaign,
        }),
      );
    } catch (_) {}
  }
}
