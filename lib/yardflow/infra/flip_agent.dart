import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/flip_gate_config.dart';

class FlipAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final components = raw
        .split('.')
        .map((part) => int.tryParse(part))
        .whereType<int>()
        .take(3)
        .toList();
    if (components.isEmpty || components.first < 18) return '18.5';
    return components.join('.');
  }

  // GAME THEME CATEGORY: crash — no UA identity suffix.
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return '${FlipGateConfig.uaProduct} '
        '${FlipGateConfig.uaPlatformPrefix} $cpu '
        '${FlipGateConfig.uaPlatformSuffix} '
        '${FlipGateConfig.uaEngine} '
        'Version/${FlipGateConfig.safariVersion} '
        '${FlipGateConfig.uaMobileToken} '
        'Safari/${FlipGateConfig.safariTail}';
  }

  String _fallback() => _mobileSafari('18.5');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
