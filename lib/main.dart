import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/analytics_service.dart';
import 'core/audio_service.dart';
import 'core/orientation.dart';
import 'core/theme.dart';
import 'screens/loading_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.images.prefix = '';
  AudioService.instance.init();
  await AnalyticsService.instance.prepare();
  runApp(const FeatherflipApp());
}

class FeatherflipApp extends StatefulWidget {
  const FeatherflipApp({super.key});

  @override
  State<FeatherflipApp> createState() => _FeatherflipAppState();
}

class _FeatherflipAppState extends State<FeatherflipApp> with WidgetsBindingObserver {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A scene restored by iOS (notably iPad) can come back in the wrong
    // orientation, and a session left open overnight needs fresh dailies.
    GameOrientation.reapplyIfLocked();
    _appState.refreshDailyState();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp(
        title: 'Featherflip Frenzy',
        debugShowCheckedModeBanner: false,
        theme: buildFFTheme(),
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        // The HUD and menu panels are laid out for a game-like fixed scale;
        // very large accessibility text sizes would otherwise clip them.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
