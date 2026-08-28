import 'package:featherflipfrenzygame/yardflow/config/flip_gate_config.dart';
import 'package:featherflipfrenzygame/yardflow/core/flip_codec.dart';

void main() {
  const expected = <String, String>{
    'config': 'https://featherflipfrenzy.com/config.php',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'appsFlyerDevKey': 'XiXiK2CRj3ZvcrsKT6rwb5',
    'firebaseProjectNumber': '806389098282',
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
    'safari': '18.5',
    'safariTail': '604.1',
  };

  final decoded = <String, String>{
    'config': FlipGateConfig.endpoint,
    'gcd': FlipGateConfig.gcdBase,
    'appsFlyerDevKey': FlipGateConfig.appsFlyerKey,
    'firebaseProjectNumber': FlipGateConfig.firebaseProjectNumber,
    'uaProduct': FlipGateConfig.uaProduct,
    'uaPlatformPrefix': FlipGateConfig.uaPlatformPrefix,
    'uaPlatformSuffix': FlipGateConfig.uaPlatformSuffix,
    'uaEngine': FlipGateConfig.uaEngine,
    'uaMobileToken': FlipGateConfig.uaMobileToken,
    'safari': FlipGateConfig.safariVersion,
    'safariTail': FlipGateConfig.safariTail,
  };

  for (final entry in expected.entries) {
    final got = decoded[entry.key]!;
    final again = unfoldYard(foldYard(entry.value));
    if (got != entry.value || again != entry.value) {
      throw StateError('FAIL ${entry.key}: got=$got again=$again');
    }
    // ignore: avoid_print
    print('OK ${entry.key}=${entry.value}');
  }

  final ua = '${FlipGateConfig.uaProduct} '
      '${FlipGateConfig.uaPlatformPrefix} 18_5 '
      '${FlipGateConfig.uaPlatformSuffix} '
      '${FlipGateConfig.uaEngine} '
      'Version/${FlipGateConfig.safariVersion} '
      '${FlipGateConfig.uaMobileToken} '
      'Safari/${FlipGateConfig.safariTail}';
  const forbidden = ['Dart', 'Flutter', 'CFNetwork', 'Darwin', 'WebView', 'appid/', 'appname/'];
  for (final token in forbidden) {
    if (ua.toLowerCase().contains(token.toLowerCase())) {
      throw StateError('UA contains $token: $ua');
    }
  }
  // ignore: avoid_print
  print('UA=$ua');
  // ignore: avoid_print
  print('grayCredentialsReady=${FlipGateConfig.grayCredentialsReady}');
  // ignore: avoid_print
  print('privacy=${FlipGateConfig.privacyUrl}');
  // ignore: avoid_print
  print('support=${FlipGateConfig.supportUrl}');
  // ignore: avoid_print
  print('storeToken=${FlipGateConfig.storeToken}');
}
