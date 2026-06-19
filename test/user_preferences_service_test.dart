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

    test('persists airplane mode airline name', () async {
      final service = UserPreferencesService.instance;

      await service.setAirplaneModeAirlineName('Emirates');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('airplane_mode_airline_name'), 'Emirates');
      expect(service.airplaneModeAirlineName, 'Emirates');
    });

    test('uses fallback airline name when saved value is blank', () async {
      final service = UserPreferencesService.instance;

      await service.setAirplaneModeAirlineName('   ');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('airplane_mode_airline_name'), 'flightprint Air');
      expect(service.airplaneModeAirlineName, 'flightprint Air');
    });
  });
}
