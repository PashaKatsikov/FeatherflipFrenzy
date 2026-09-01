import 'package:featherflipfrenzygame/yardflow/core/flip_models.dart';
import 'package:featherflipfrenzygame/yardflow/infra/flip_pulse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlipPulse.extract', () {
    test('reads top-level url keys', () {
      expect(
        FlipPulse.extract(<String, dynamic>{
          'url': 'https://partner.example/offer?x=1',
        }),
        'https://partner.example/offer?x=1',
      );
      expect(
        FlipPulse.extract(<String, dynamic>{
          'deep_link': 'https://yard.example/a',
        }),
        'https://yard.example/a',
      );
    });

    test('reads nested data / payload / fcm_options', () {
      expect(
        FlipPulse.extract(<String, dynamic>{
          'data': <String, dynamic>{'link': 'https://nested.example/path'},
        }),
        'https://nested.example/path',
      );
      expect(
        FlipPulse.extract(<String, dynamic>{
          'payload': '{"href":"https://json.example/x"}',
        }),
        'https://json.example/x',
      );
      expect(
        FlipPulse.extract(<String, dynamic>{
          'fcm_options': <String, dynamic>{'link': 'https://fcm.example/l'},
        }),
        'https://fcm.example/l',
      );
    });

    test('rejects non-http values', () {
      expect(
        FlipPulse.extract(<String, dynamic>{'url': 'javascript:alert(1)'}),
        isNull,
      );
      expect(
        FlipPulse.extract(<String, dynamic>{'url': '/relative'}),
        isNull,
      );
      expect(FlipPulse.extract(<String, dynamic>{}), isNull);
    });
  });

  group('WebYard', () {
    test('push destinations open immediately', () {
      const push = WebYard(
        'https://example.com',
        coldLaunch: true,
        fromPush: true,
      );
      expect(push.openImmediately, isTrue);
      const organic = WebYard('https://example.com');
      expect(organic.openImmediately, isFalse);
    });
  });
}
