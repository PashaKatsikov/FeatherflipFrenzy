import 'package:audioplayers/audioplayers.dart';

/// Thin wrapper around `audioplayers` providing a small round-robin pool of
/// players so overlapping sound effects never cut each other off.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final List<AudioPlayer> _sfxPool = List.generate(6, (i) => AudioPlayer(playerId: 'ff_sfx_$i'));
  int _sfxCursor = 0;

  bool sfxEnabled = true;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    for (final p in _sfxPool) {
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
    }
  }

  void setSfxEnabled(bool enabled) {
    sfxEnabled = enabled;
  }

  Future<void> playSfx(String asset, {double volume = 1.0}) async {
    if (!sfxEnabled) return;
    try {
      final player = _sfxPool[_sfxCursor];
      _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _sfxPool) {
      await p.dispose();
    }
  }
}
