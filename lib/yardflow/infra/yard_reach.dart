import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class YardReach {
  final Connectivity _connectivity = Connectivity();

  /// Budget for a single reachability probe. A cellular hand-off or a busy
  /// radio routinely needs more than a few hundred milliseconds, and every
  /// premature verdict here costs an offline screen shown to an online player.
  static const Duration _probeWindow = Duration(milliseconds: 1585);

  /// Whether the OS currently claims a usable interface. Only the boot
  /// pipeline uses this, to keep a returning offline player inside the game
  /// instead of stalling on a probe.
  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Factual reachability. The interface state reported by the OS is
  /// deliberately not consulted: it reads `none` for a moment during a
  /// Wi-Fi/cellular hand-off and a VPN can hide the radio entirely, both of
  /// which would strand a perfectly online player on the offline screen.
  /// Neither probe touches our own domain, so an unpropagated app host cannot
  /// force a false verdict either. The first success wins immediately; a
  /// negative answer waits for every probe to fail.
  Future<bool> canReachNetwork() async {
    final probes = <Future<bool>>[_httpPulse(), _dnsPulse()];
    final verdict = Completer<bool>();
    var outstanding = probes.length;
    for (final probe in probes) {
      probe.then((reachable) {
        if (reachable) {
          if (!verdict.isCompleted) verdict.complete(true);
          return;
        }
        outstanding--;
        if (outstanding == 0 && !verdict.isCompleted) verdict.complete(false);
      });
    }
    return verdict.future;
  }

  Future<bool> _httpPulse() async {
    final client = HttpClient()..connectionTimeout = _probeWindow;
    try {
      final request = await client
          .getUrl(Uri.parse('https://www.apple.com/library/test/success.html'))
          .timeout(_probeWindow);
      request.followRedirects = false;
      final response = await request.close().timeout(_probeWindow);
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _dnsPulse() async {
    final hits = await Future.wait(
      <String>['cloudflare.com', 'one.one.one.one'].map((host) async {
        try {
          final records = await InternetAddress.lookup(host).timeout(
            _probeWindow,
          );
          return records.any((record) => record.rawAddress.isNotEmpty);
        } catch (_) {
          return false;
        }
      }),
    );
    return hits.any((hit) => hit);
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
