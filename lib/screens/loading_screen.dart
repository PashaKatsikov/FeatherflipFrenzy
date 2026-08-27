import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics_service.dart';
import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/orientation.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'main_menu_screen.dart';

/// The very first screen shown. Unlike the rest of the game, it supports
/// both portrait and landscape (per the product spec) and swaps its artwork
/// accordingly while it warms up every image/audio asset used later on.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    GameOrientation.allowLoadingOrientations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEverything());
  }

  Future<void> _loadEverything() async {
    final stopwatch = Stopwatch()..start();
    final allImagePaths = <String>{
      ...Sprites.preloadList,
      UiImages.logo,
    };
    var completed = 0;
    final total = allImagePaths.length + 1; // +1 for Flame's cache pass

    void bump() {
      completed++;
      if (mounted) {
        setState(() => _progress = completed / total);
      }
    }

    for (final path in allImagePaths) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
      bump();
    }

    try {
      await Flame.images.loadAll(Sprites.preloadList.map((p) => p).toList());
    } catch (_) {}
    bump();

    if (!mounted) return;
    final appState = context.read<AppState>();
    // Bounded wait: a failed read still flips the flag, but never hang the
    // splash screen if something unexpected keeps it pending.
    var waited = 0;
    while (!appState.isLoaded && waited < 5000 && mounted) {
      await Future.delayed(const Duration(milliseconds: 30));
      waited += 30;
    }
    if (!mounted) return;
    AudioService.instance.setSfxEnabled(appState.sfxOn);
    Haptics.instance.setEnabled(appState.vibrationOn);
    await AnalyticsService.instance.start();

    final elapsed = stopwatch.elapsedMilliseconds;
    const minDisplayMs = 1100;
    if (elapsed < minDisplayMs) {
      await Future.delayed(Duration(milliseconds: minDisplayMs - elapsed));
    }

    if (!mounted || _navigated) return;
    _navigated = true;
    await GameOrientation.lockLandscape();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FFColors.richGreen,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final asset = isPortrait ? UiImages.loadingVertical : UiImages.loadingHorizontal;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
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
                              Container(color: Colors.black.withValues(alpha: 0.35)),
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 180),
                                widthFactor: _progress.clamp(0.03, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [FFColors.warmYellow, FFColors.gold]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loading the farm...',
                        style: FFText.body(size: 15, color: Colors.white).copyWith(
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
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
