import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/services/booking_provider_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BookingProviderService', () {
    setUp(() {
      // Reset shared preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('getSelectedProvider', () {
      test('returns Skyscanner as default when no provider is saved', () async {
        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.skyscanner);
      });

      test('returns saved Skyscanner provider', () async {
        await BookingProviderService.setSelectedProvider(
          BookingProvider.skyscanner,
        );
        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.skyscanner);
      });

      test('returns saved Google Flights provider', () async {
        await BookingProviderService.setSelectedProvider(
          BookingProvider.googleFlights,
        );
        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.googleFlights);
      });

      test('returns saved Kayak provider', () async {
        await BookingProviderService.setSelectedProvider(BookingProvider.kayak);
        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.kayak);
      });

      test('returns Skyscanner when saved value is corrupted', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('booking_provider', 'invalid_provider');
        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.skyscanner);
      });
    });

    group('setSelectedProvider', () {
      test('saves Skyscanner provider', () async {
        final success = await BookingProviderService.setSelectedProvider(
          BookingProvider.skyscanner,
        );
        expect(success, true);

        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.skyscanner);
      });

      test('saves Google Flights provider', () async {
        final success = await BookingProviderService.setSelectedProvider(
          BookingProvider.googleFlights,
        );
        expect(success, true);

        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.googleFlights);
      });

      test('saves Kayak provider', () async {
        final success = await BookingProviderService.setSelectedProvider(
          BookingProvider.kayak,
        );
        expect(success, true);

        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.kayak);
      });

      test('overwrites previously saved provider', () async {
        await BookingProviderService.setSelectedProvider(
          BookingProvider.skyscanner,
        );
        var provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.skyscanner);

        await BookingProviderService.setSelectedProvider(
          BookingProvider.googleFlights,
        );
        provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.googleFlights);
      });
    });

    group('clearProvider', () {
      test('removes saved provider and returns true', () async {
        await BookingProviderService.setSelectedProvider(BookingProvider.kayak);

        final success = await BookingProviderService.clearProvider();
        expect(success, true);

        final provider = await BookingProviderService.getSelectedProvider();
        expect(provider, BookingProvider.skyscanner);
      });

      test('returns true even when no provider is saved', () async {
        final success = await BookingProviderService.clearProvider();
        expect(success, true);
      });
    });

    group('BookingProvider enum', () {
      test('has correct display names', () {
        expect(BookingProvider.skyscanner.displayName, 'Skyscanner');
        expect(BookingProvider.googleFlights.displayName, 'Google Flights');
        expect(BookingProvider.kayak.displayName, 'Kayak');
      });

      test('all providers are accessible', () {
        expect(BookingProvider.values.length, 3);
        expect(
          BookingProvider.values.contains(BookingProvider.skyscanner),
          true,
        );
        expect(
          BookingProvider.values.contains(BookingProvider.googleFlights),
          true,
        );
        expect(BookingProvider.values.contains(BookingProvider.kayak), true);
      });
    });
  });
}
