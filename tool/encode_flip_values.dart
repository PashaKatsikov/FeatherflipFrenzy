// ignore_for_file: avoid_print

import 'package:featherflipfrenzygame/yardflow/core/flip_codec.dart';

void main() {
  const values = <String, String>{
    'config': 'https://featherflipfrenzy.com/config.php',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.5',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'XiXiK2CRj3ZvcrsKT6rwb5',
    'firebaseProjectNumber': '806389098282',
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
  };

  for (final entry in values.entries) {
    final encoded = foldYard(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    final back = unfoldYard(encoded);
    if (back != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}: "$back"');
    }
  }
  print('VERIFY: all values round-tripped');
}
