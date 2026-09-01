import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio_service.dart';
import 'core/notification_service.dart';
import 'core/orientation.dart';
import 'core/theme.dart';
import 'screens/loading_screen.dart';
import 'screens/yard_splash.dart';
import 'state/app_state.dart';
import 'yardflow/config/flip_gate_config.dart';
import 'yardflow/flip_coordinator.dart';
import 'yardflow/infra/flip_agent.dart';
import 'yardflow/infra/flip_pulse.dart';
import 'yardflow/infra/flip_tap_bridge.dart';
import 'yardflow/infra/flip_trace.dart';
import 'yardflow/infra/gate_dispatch.dart';
import 'yardflow/infra/yard_locker.dart';
import 'yardflow/infra/yard_reach.dart';
import 'yardflow/infra/yard_tracker.dart';
import 'yardflow/pages/yard_browser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.images.prefix = '';
  AudioService.instance.init();
  await NotificationService.instance.init();

  final locker = YardLocker();
  final agent = FlipAgent();
  await Future.wait<void>(<Future<void>>[
    locker.initialize(),
    agent.prepare(),
  ]);

  flipTrace(
    () => '[FF.COOP] creds=${FlipGateConfig.grayCredentialsReady} '
        'endpoint=${FlipGateConfig.endpoint}',
  );

  var productionServicesReady = false;
  if (FlipGateConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
      flipTrace(() => '[FF.COOP] Firebase ready');
    } catch (error) {
      flipTrace(() => '[FF.COOP] Firebase failed: $error');
    }
    if (productionServicesReady) {
      FirebaseMessaging.onBackgroundMessage(flipBackgroundMessage);
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        flipTrace(() => '[FF.COOP] AppCheck skipped: $error');
      }
    }
  }

  final reach = YardReach();
  final pulse = FlipPulse(locker, enabled: productionServicesReady);
  final tracker = YardTracker(agent);
  final coordinator = FlipCoordinator(
    locker: locker,
    reach: reach,
    tracker: tracker,
    dispatch: GateDispatch(agent, locker),
    pulse: pulse,
    agent: agent,
    runtimeEnabled: FlipGateConfig.grayCredentialsReady,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF3E9E3B),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(FeatherflipApp(coordinator: coordinator));
}

class FeatherflipApp extends StatefulWidget {
  const FeatherflipApp({super.key, this.coordinator});

  final FlipCoordinator? coordinator;

  @override
  State<FeatherflipApp> createState() => _FeatherflipAppState();
}

class _FeatherflipAppState extends State<FeatherflipApp>
    with WidgetsBindingObserver {
  final AppState _appState = AppState();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final coordinator = widget.coordinator;
    if (coordinator != null) {
      coordinator.pulse.onOrphanDestination = _openPushUrl;
      unawaited(coordinator.pulse.captureLaunchTap());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.coordinator?.pulse.onOrphanDestination = null;
    _appState.dispose();
    super.dispose();
  }

  void _openPushUrl(String url) {
    unawaited(_openPushUrlAsync(url));
  }

  Future<void> _openPushUrlAsync(String url) async {
    final coordinator = widget.coordinator;
    if (coordinator == null) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    await coordinator.locker.persistPushDestination(trimmed);
    if (!coordinator.claimPushOpen(trimmed)) return;

    NavigatorState? nav = _navigatorKey.currentState;
    for (var attempt = 0; attempt < 12 && nav == null; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      nav = _navigatorKey.currentState;
    }
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => YardBrowser(
          url: trimmed,
          coldLaunch: true,
          locker: coordinator.locker,
          reach: coordinator.reach,
          pulse: coordinator.pulse,
          agent: coordinator.agent,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _reopenNativeTap() async {
    final coordinator = widget.coordinator;
    if (coordinator == null) return;
    // A mounted browser consumes the tap itself and loads it in place.
    if (coordinator.pulse.onDestination != null) return;
    final tapped = await FlipTapBridge.consume();
    if (tapped == null || tapped.isEmpty) return;
    await coordinator.locker.persistPushDestination(tapped);
    await _openPushUrlAsync(tapped);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    GameOrientation.reapplyIfLocked();
    _appState.refreshDailyState();
    unawaited(_reopenNativeTap());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Featherflip Frenzy',
        debugShowCheckedModeBanner: false,
        theme: buildFFTheme(),
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: child ?? const SizedBox.shrink(),
        ),
        home: widget.coordinator == null
            ? const LoadingScreen()
            : YardSplash(coordinator: widget.coordinator!),
      ),
    );
  }
}
