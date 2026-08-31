import 'dart:async';
import 'dart:io';

import 'config/flip_gate_config.dart';
import 'core/flip_models.dart';
import 'infra/flip_agent.dart';
import 'infra/flip_pulse.dart';
import 'infra/flip_tap_bridge.dart';
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

  Future<FlipDestination> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<FlipDestination> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      flipTrace(
        () => '[FF.COOP] gate off runtime=$runtimeEnabled '
            'creds=${FlipGateConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const YardHome();
    }

    flipTrace(() => '[FF.COOP] decide start route=${locker.route}');
    pulse.onTokenChanged = _refreshForToken;
    await pulse.captureLaunchTap();
    final coldRoute =
        await FlipTapBridge.consume() ?? await locker.consumePushUrl();
    if (coldRoute != null) {
      if (!await _liveNetwork()) {
        await locker.stashPushUrl(coldRoute);
        await locker.saveRoute(FlipRoute.web);
        return const QuietYard(returnToYard: false);
      }
      await locker.saveRoute(FlipRoute.web);
      await locker.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return WebYard(coldRoute, coldLaunch: true);
    }

    if (locker.route != FlipRoute.yard && !await _liveNetwork()) {
      return const QuietYard(returnToYard: false);
    }

    onProgress(0.12);
    return switch (locker.route) {
      FlipRoute.fresh => _firstDecision(onProgress),
      FlipRoute.web => _returningWeb(onProgress),
      FlipRoute.yard => _returningYard(onProgress),
    };
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
    final pending = await locker.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return WebYard(pending);
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
