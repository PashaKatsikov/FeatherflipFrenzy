import 'dart:async';
import 'dart:io';

import 'config/flip_gate_config.dart';
import 'core/flip_models.dart';
import 'infra/flip_agent.dart';
import 'infra/flip_pulse.dart';
import 'infra/flip_trace.dart';
import 'infra/gate_dispatch.dart';
import 'infra/yard_locker.dart';
import 'infra/yard_reach.dart';
import 'infra/yard_tracker.dart';

class FlipCoordinator {
  FlipCoordinator({
    required this.locker,
    required this.reach,
    required this.tracker,
    required this.dispatch,
    required this.pulse,
    required this.agent,
    required this.runtimeEnabled,
  });

  final YardLocker locker;
  final YardReach reach;
  final YardTracker tracker;
  final GateDispatch dispatch;
  final FlipPulse pulse;
  final FlipAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && FlipGateConfig.grayCredentialsReady;

  Future<FlipDestination>? _decideFuture;
  String? _lastPushOpen;
  DateTime? _lastPushOpenAt;

  /// The splash and the app-level tap listener can both react to one tap;
  /// only the first caller gets to navigate.
  bool claimPushOpen(String url) {
    final now = DateTime.now();
    if (_lastPushOpen == url &&
        _lastPushOpenAt != null &&
        now.difference(_lastPushOpenAt!) < const Duration(seconds: 3)) {
      return false;
    }
    _lastPushOpen = url;
    _lastPushOpenAt = now;
    return true;
  }

  Future<FlipDestination> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<FlipDestination> _decide({
    required void Function(double value) onProgress,
  }) async {
    pulse.onTokenChanged = _refreshForToken;

    var pushUrl = await pulse.takePushUrl();
    if (pushUrl == null) {
      await pulse.captureLaunchTap();
      pushUrl = await pulse.takePushUrl();
    } else {
      unawaited(pulse.captureLaunchTap());
    }
    if (pushUrl != null) {
      flipTrace(() => '[FF.COOP] push dest=$pushUrl');
      return _openPush(pushUrl, onProgress);
    }

    if (!enabled) {
      flipTrace(
        () => '[FF.COOP] gate off runtime=$runtimeEnabled '
            'creds=${FlipGateConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const YardHome();
    }

    flipTrace(() => '[FF.COOP] decide start route=${locker.route}');

    if (locker.route != FlipRoute.yard && !await _liveNetwork()) {
      return const QuietYard(returnToYard: false);
    }

    onProgress(0.12);
    final decided = await switch (locker.route) {
      FlipRoute.fresh => _firstDecision(onProgress),
      FlipRoute.web => _returningWeb(onProgress),
      FlipRoute.yard => _returningYard(onProgress),
    };
    return await _preferFreshPush(decided);
  }

  Future<FlipDestination> _openPush(
    String url,
    void Function(double) onProgress,
  ) async {
    await locker.persistPushDestination(url);
    if (!await _liveNetwork()) {
      return const QuietYard(returnToYard: false);
    }
    unawaited(_backgroundDispatch());
    onProgress(1);
    return WebYard(url, coldLaunch: true, fromPush: true);
  }

  Future<FlipDestination> _preferFreshPush(FlipDestination decided) async {
    final latest = await pulse.takePushUrl();
    if (latest == null) return decided;
    return WebYard(latest, coldLaunch: true, fromPush: true);
  }

  Future<bool> _liveNetwork() async {
    try {
      return await reach.canReachNetwork();
    } catch (_) {
      return false;
    }
  }

  Future<FlipDestination> _firstDecision(
    void Function(double) progress,
  ) async {
    progress(0.32);
    await Future.wait<void>(<Future<void>>[
      tracker.ensureConsent(),
      pulse.boot(),
    ]);
    final midPush = await pulse.takePushUrl();
    if (midPush != null) {
      progress(1);
      return WebYard(midPush, coldLaunch: true, fromPush: true);
    }
    progress(0.52);
    await tracker.awaitSignals();
    progress(0.78);
    final reply = await _requestConfig();
    progress(1);
    flipTrace(
      () => '[FF.COOP] first dest=${reply.hasDestination} url=${reply.url}',
    );
    if (reply.hasDestination) {
      await locker.saveRoute(FlipRoute.web);
      return WebYard(reply.url!);
    }
    await locker.saveRoute(FlipRoute.yard);
    return const YardHome();
  }

  Future<FlipDestination> _returningWeb(
    void Function(double) progress,
  ) async {
    final pending = await locker.peekPushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return WebYard(pending, coldLaunch: true, fromPush: true);
    }
    final cached = await locker.savedUrl();
    if (cached != null && !locker.cachedUrlExpired) {
      progress(1);
      return WebYard(cached);
    }

    if (!await reach.canReachNetwork()) {
      return const QuietYard(returnToYard: false);
    }
    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      tracker.start(),
    ]);
    final midPush = await pulse.takePushUrl();
    if (midPush != null) {
      progress(1);
      return WebYard(midPush, coldLaunch: true, fromPush: true);
    }
    progress(0.62);
    await tracker.awaitSignals(
      installTimeout: const Duration(seconds: FlipGateConfig.installSignalSeconds),
    );
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return WebYard(reply.url!);
    return const QuietYard(returnToYard: false);
  }

  Future<FlipDestination> _returningYard(
    void Function(double) progress,
  ) async {
    if (!await reach.hasInterface()) {
      progress(1);
      return const YardHome();
    }
    if (!await reach.canReachNetwork()) {
      progress(1);
      return const YardHome();
    }
    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      tracker.start(),
    ]);
    final midPush = await pulse.takePushUrl();
    if (midPush != null) {
      progress(1);
      return WebYard(midPush, coldLaunch: true, fromPush: true);
    }
    progress(0.55);
    await tracker.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const YardHome();
    await locker.saveRoute(FlipRoute.web);
    return WebYard(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await tracker.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return dispatch.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        tracker.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
