import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/eco_tip_service.dart';
import 'package:my_app/services/emissions_service.dart';

void main() {
  group('EmissionsService.debugScrub', () {
    test('replaces key in middle of string', () {
      const key = 'AIzaSyABC123';
      expect(
        EmissionsService.debugScrub('error: AIzaSyABC123 invalid', key),
        'error: [REDACTED] invalid',
      );
    });

    test('leaves string unchanged if key is empty', () {
      expect(EmissionsService.debugScrub('hello world', ''), 'hello world');
      expect(EmissionsService.debugScrub('hello world', '   '), 'hello world');
    });

    test('leaves string unchanged if key absent', () {
      expect(
        EmissionsService.debugScrub('no secrets here', 'AIzaSyXYZ'),
        'no secrets here',
      );
    });
  });

  group('EcoTipService.debugScrub', () {
    test('replaces key in middle of string', () {
      const key = 'sk-openai-XYZ';
      expect(
        EcoTipService.debugScrub('failed with sk-openai-XYZ token', key),
        'failed with [REDACTED] token',
      );
    });

    test('leaves string unchanged if key is empty', () {
      expect(EcoTipService.debugScrub('payload', ''), 'payload');
    });

    test('leaves string unchanged if key absent', () {
      expect(
        EcoTipService.debugScrub('clean string', 'sk-missing'),
        'clean string',
      );
    });
  });
}
