import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/notification_service.dart';
import '../core/orientation.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../yardflow/core/flip_models.dart';
import '../yardflow/flip_coordinator.dart';
import '../yardflow/pages/quiet_yard_page.dart';
import '../yardflow/pages/yard_browser.dart';
import '../yardflow/pages/yard_invite.dart';
import 'main_menu_screen.dart';

class YardSplash extends StatefulWidget {
  const YardSplash({super.key, required this.coordinator});

  final FlipCoordinator coordinator;

  @override
  State<YardSplash> createState() => _YardSplashState();
}

class _YardSplashState extends State<YardSplash> {
  double _gateProgress = 0;
  FlipDestination? _destination;
  bool _started = false;
  bool _leaving = false;
  late final DateTime _startedAt;
  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    GameOrientation.allowLoadingOrientations();
    _deadline = Timer(const Duration(seconds: 13), () {
      if (mounted && !_leaving) {
        _destination ??= const YardHome();
        _maybeLeave();
      }
    });
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _runGate();
  }

  Future<void> _runGate() async {
    try {
      _destination = await widget.coordinator.decide(
        onProgress: (value) {
          if (mounted && !_leaving) {
            setState(() => _gateProgress = value.clamp(0.0, 1.0));
          }
        },
      );
    } catch (_) {
      _destination = const YardHome();
    }
    if (!mounted || _leaving) return;
    if (_destination is QuietYard) {
      _leaving = true;
      _deadline?.cancel();
      await _open(_destination!);
      return;
    }
    if (mounted) setState(() => _gateProgress = 1);
    _maybeLeave();
  }

  Future<void> _maybeLeave() async {
    if (_leaving || _destination == null) return;
    final elapsed = DateTime.now().difference(_startedAt);
    const floor = Duration(milliseconds: 1650);
    if (elapsed < floor) {
      await Future<void>.delayed(floor - elapsed);
    }
    if (!mounted || _leaving) return;
    _leaving = true;
    _deadline?.cancel();
    await _open(_destination!);
  }

  Future<void> _open(FlipDestination destination) async {
    final coordinator = widget.coordinator;

    if (destination is QuietYard) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuietYardPage(
            reach: coordinator.reach,
            retryBuilder: (_) => YardSplash(coordinator: coordinator),
          ),
        ),
      );
      return;
    }

    if (destination is WebYard) {
      Widget browser(BuildContext _) => YardBrowser(
        url: destination.url,
        coldLaunch: destination.coldLaunch,
        locker: coordinator.locker,
        reach: coordinator.reach,
        pulse: coordinator.pulse,
        agent: coordinator.agent,
      );

      if (coordinator.locker.shouldShowPushInvite &&
          await coordinator.pulse.canOfferPermission()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => YardInvite(
              locker: coordinator.locker,
              pulse: coordinator.pulse,
              nextBuilder: browser,
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: browser),
      );
      return;
    }

    await _warmYardThenMenu();
  }

  Future<void> _warmYardThenMenu() async {
    final allImagePaths = <String>{
      ...Sprites.preloadList,
      UiImages.logo,
    };
    for (final path in allImagePaths) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
    try {
      await Flame.images.loadAll(Sprites.preloadList.toList());
    } catch (_) {}
    if (!mounted) return;
    final appState = context.read<AppState>();
    var waited = 0;
    while (!appState.isLoaded && waited < 5000 && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      waited += 30;
    }
    if (!mounted) return;
    AudioService.instance.setSfxEnabled(appState.sfxOn);
    Haptics.instance.setEnabled(appState.vibrationOn);
    if (appState.notificationsOn) {
      await NotificationService.instance.scheduleDaily(
        hour: appState.notificationHour,
        minute: appState.notificationMinute,
      );
    }
    await GameOrientation.lockLandscape();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FFColors.richGreen,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final asset = isPortrait
              ? UiImages.loadingVertical
              : UiImages.loadingHorizontal;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
              if (_destination is! QuietYard)
              Positioned(
                left: 0,
                right: 0,
                bottom: isPortrait ? 70 : 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 16,
                          child: Stack(
                            children: [
                              Container(
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 195),
                                widthFactor: _gateProgress.clamp(0.03, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        FFColors.warmYellow,
                                        FFColors.gold,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LoadingDotsLabel(
                        style: FFText.body(size: 22.5, color: Colors.white)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
