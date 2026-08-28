import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/flip_gate_config.dart';
import 'flip_agent.dart';
import 'flip_trace.dart';

class YardTracker {
  YardTracker(this._agent);

  final FlipAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  Future<void>? _consentFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> ensureConsent() => _consentFuture ??= _requestConsent();

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!FlipGateConfig.grayCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      await ensureConsent();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: FlipGateConfig.appsFlyerKey,
          appId: FlipGateConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 9,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flat(raw));
      sdk.onDeepLinking((result) {
        final event = result.deepLink?.clickEvent;
        if (event != null) _deepLink = Map<String, dynamic>.from(event);
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      flipTrace(() => '[FF.COOP] tracker init failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _requestConsent() async {
    if (!Platform.isIOS) return;
    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await _waitUntilFrontmost();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(
      const Duration(milliseconds: FlipGateConfig.attPromptDelayMs),
    );
    await AppTrackingTransparency.requestTrackingAuthorization();
    status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await _waitUntilFrontmost();
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _waitUntilFrontmost() async {
    for (var i = 0; i < 14; i++) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) return;
      await Future<void>.delayed(const Duration(milliseconds: 110));
    }
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flat(raw);
      final status = received['status']?.toString().toLowerCase();
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      flipTrace(
        () => '[FF.COOP] conversion status=$status '
            'af_status=${received['af_status']}',
      );
      if (failed) {
        _install = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        await Future<void>.delayed(
          const Duration(seconds: FlipGateConfig.organicRecheckSeconds),
        );
        _install = await _fetchGcd() ?? received;
      } else {
        _install = received;
      }
    } catch (error) {
      flipTrace(() => '[FF.COOP] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installReady.isCompleted) _installReady.complete();
    }
  }

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      final uri = Uri.parse(
        '${FlipGateConfig.gcdBase}id${FlipGateConfig.iosStoreId}?device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${FlipGateConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration? installTimeout,
  }) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(
        installTimeout ??
            const Duration(seconds: FlipGateConfig.installSignalSeconds),
        onTimeout: () {},
      ),
      _deepLinkReady.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    if (_reopen != null) {
      _reopen!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }
    if (_deepLink != null) {
      _deepLink!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = FlipGateConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = FlipGateConfig.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        FlipGateConfig.firebaseProjectNumber.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = FlipGateConfig.firebaseProjectNumber;
    }

    if (Platform.isIOS) {
      try {
        if (await AppTrackingTransparency.trackingAuthorizationStatus ==
            TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body['sub_id_10'] = idfa;
          }
        }
      } catch (_) {}
    }
    flipTrace(() => '[FF.COOP] payload ${jsonEncode(body)}');
    return body;
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
