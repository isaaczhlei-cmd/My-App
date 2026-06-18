import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/services/user_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await UserPreferencesService.instance.setTinyFlightAnimationEnabled(true);
    });

    test('persists airplane mode preference', () async {
      final service = UserPreferencesService.instance;

      await service.setTinyFlightAnimationEnabled(false);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tiny_flight_animation_enabled'), isFalse);

      await service.setTinyFlightAnimationEnabled(true);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tiny_flight_animation_enabled'), isTrue);
    });

    test('loads saved airplane mode preference', () async {
      SharedPreferences.setMockInitialValues({
        'tiny_flight_animation_enabled': false,
      });

      final service = UserPreferencesService.instance;
      await service.load();

      expect(service.tinyFlightAnimationEnabled, isFalse);
    });
  });
}
