import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/theme.dart';
import '../game/featherflip_game.dart';
import '../models/round_result.dart';
import '../models/yard_challenge.dart';
import '../models/zone.dart';
import '../state/app_state.dart';
import '../widgets/coin_badge.dart';
import '../widgets/ff_button.dart';
import '../widgets/virtual_joystick.dart';
import 'round_results_screen.dart';
import 'zone_unlock_screen.dart';

class GameScreen extends StatefulWidget {
  final ZoneDef zone;
  final YardChallenge? challenge;
  const GameScreen({super.key, required this.zone, this.challenge});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late FeatherflipGame _game;
  bool _paused = false;
  bool _showTutorial = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final appState = context.read<AppState>();
    _game = FeatherflipGame(
      zone: widget.zone,
      appState: appState,
      onRoundEnd: _onRoundEnd,
      challenge: widget.challenge,
    );
    _showTutorial = widget.zone.index == 0 && !appState.hasSeenTutorial;
    if (_showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _game.pauseEngine());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.disposeNotifiers();
    super.dispose();
  }

  /// Losing focus (incoming call, app switcher, notification shade) must not
  /// keep the round timer running in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;
    final leavingForeground = state != AppLifecycleState.resumed;
    if (leavingForeground && !_paused && !_showTutorial) {
      setState(() => _paused = true);
      _game.pauseEngine();
    }
  }

  void _setPaused(bool value) {
    setState(() {
      _paused = value;
      if (_paused) {
        _game.stopMoving();
        _game.pauseEngine();
      } else {
        _game.resumeEngine();
      }
    });
  }

  void _togglePause() => _setPaused(!_paused);

  void _dismissTutorial() {
    context.read<AppState>().markTutorialSeen();
    setState(() => _showTutorial = false);
    _game.resumeEngine();
  }

  void _onRoundEnd(RoundResult result) {
    if (_finished || !mounted) return;
    _finished = true;
    Future.microtask(() {
      if (!mounted) return;
      if (result.unlockedNewZone && result.zone.index + 1 < kZones.length) {
        final nextZone = kZones[result.zone.index + 1];
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ZoneUnlockScreen(zone: nextZone, result: result)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RoundResultsScreen(result: result)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // An accidental edge swipe must not throw the player out of a live round;
    // it opens the pause menu instead, where leaving is an explicit choice.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _finished) return;
        if (!_paused && !_showTutorial) _setPaused(true);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: _game),
            _buildHud(),
            if (!_paused && !_showTutorial)
              Positioned(
                left: 10,
                bottom: 10,
                child: SafeArea(
                  child: VirtualJoystick(
                    onDirection: (dir) => _game.setMoveDirection(Vector2(dir.dx, dir.dy)),
                    onFlick: _game.triggerFlickDash,
                    onRelease: _game.stopMoving,
                  ),
                ),
              ),
            if (_paused) _PauseOverlay(zone: widget.zone, challenge: widget.challenge, onResume: () => _setPaused(false)),
            if (_showTutorial) _TutorialOverlay(onDismiss: _dismissTutorial),
          ],
        ),
      ),
    );
  }

  Widget _buildHud() {
    final appState = context.watch<AppState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoinBadge(amount: appState.coins, fontSize: 17),
                const SizedBox(width: 10),
                ValueListenableBuilder<int>(
                  valueListenable: _game.streak,
                  builder: (context, streak, _) => _StreakBadge(streak: streak),
                ),
                const Spacer(),
                ValueListenableBuilder<double>(
                  valueListenable: _game.timeRemaining,
                  builder: (context, t, _) => _TimerBadge(seconds: t),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FFColors.panelBrownDark.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD9A971), width: 2),
                    ),
                    child: const Icon(Icons.pause_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _game.bannerText,
              builder: (context, text, _) {
                if (text == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: AnimatedOpacity(
                    key: ValueKey(text),
                    opacity: 1,
                    duration: const Duration(milliseconds: 215),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: FFColors.gold.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(text, style: FFText.stat(size: 15, color: FFColors.textDark)),
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: _game.rescueCharges,
                  builder: (context, charges, _) => _RescueButton(
                    charges: charges,
                    onTap: () => _game.triggerRescueDash(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FFColors.panelBrownDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9A971), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, color: streak > 0 ? Colors.orangeAccent : Colors.white38, size: 20),
          const SizedBox(width: 4),
          Text('$streak', style: FFText.stat(size: 17)),
        ],
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final double seconds;
  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final s = seconds.ceil().clamp(0, 999);
    final low = s <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (low ? Colors.red.shade900 : FFColors.panelBrownDark).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9A971), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text('$s s', style: FFText.stat(size: 16)),
        ],
      ),
    );
  }
}

class _RescueButton extends StatelessWidget {
  final int charges;
  final VoidCallback onTap;
  const _RescueButton({required this.charges, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = charges > 0;
    return GestureDetector(
      onTap: enabled
          ? () {
              AudioService.instance.playSfx(Sfx.buttonTap);
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [FFColors.warmYellow, FFColors.gold], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
              Positioned(
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: FFColors.panelBrownDark, borderRadius: BorderRadius.circular(10)),
                  child: Text('$charges', style: FFText.stat(size: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final ZoneDef zone;
  final YardChallenge? challenge;
  final VoidCallback onResume;
  const _PauseOverlay({required this.zone, required this.challenge, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD9A971), width: 3),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('PAUSED', style: FFText.title(size: 24)),
                    const SizedBox(height: 16),
                    FFButton(label: 'Resume', style: FFButtonStyle.green, width: 240, height: 52, onPressed: onResume),
                    const SizedBox(height: 10),
                    FFButton(
                      label: 'Restart',
                      style: FFButtonStyle.blue,
                      width: 240,
                      height: 52,
                      onPressed: () {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(zone: zone, challenge: challenge)));
                      },
                    ),
                    const SizedBox(height: 10),
                    FFButton(
                      label: 'Exit',
                      style: FFButtonStyle.red,
                      width: 240,
                      height: 52,
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const _TutorialOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD9A971), width: 3),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: FFColors.warmYellow, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        'Use the joystick on the left to run. Flick it to Feather Flip and knock eggs into a nest!',
                        textAlign: TextAlign.center,
                        style: FFText.body(size: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Water carries eggs away - use bridges and islands, or spend a Rescue Dash to save them.',
                        textAlign: TextAlign.center,
                        style: FFText.body(size: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FFButton(label: 'Got it!', style: FFButtonStyle.gold, width: 200, onPressed: onDismiss),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
