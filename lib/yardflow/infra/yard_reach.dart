import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class YardReach {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Real reachability: no radio → fail immediately; otherwise a short
  /// HTTP ping, then a parallel DNS fallback.
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    final probes = await Future.wait(<Future<bool>>[_httpPulse(), _dnsPulse()]);
    return probes.any((hit) => hit);
  }

  Future<bool> _httpPulse() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 740);
    try {
      final request = await client
          .getUrl(Uri.parse('https://www.apple.com/library/test/success.html'))
          .timeout(const Duration(milliseconds: 740));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(milliseconds: 740),
      );
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
          final records = await InternetAddress.lookup(
            host,
          ).timeout(const Duration(milliseconds: 740));
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
