import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/booking_link_service.dart';
import 'package:my_app/services/emissions_service.dart';

void main() {
  const service = BookingLinkService();
  final request = BookingSearchRequest(
    origin: 'JFK',
    destination: 'LAX',
    departureDate: DateTime(2026, 7, 4),
    passengers: 2,
    cabinClass: CabinClass.business,
  );

  group('BookingLinkService', () {
    test('builds Skyscanner day-view URI with route, date, and cabin', () {
      final uri = service.skyscannerUri(request);

      expect(uri.host, 'www.skyscanner.net');
      expect(uri.path, '/g/referrals/v1/flights/day-view/');
      expect(uri.queryParameters['origin'], 'JFK');
      expect(uri.queryParameters['destination'], 'LAX');
      expect(uri.queryParameters['outboundDate'], '2026-07-04');
      expect(uri.queryParameters['adultsv2'], '2');
      expect(uri.queryParameters['cabinclass'], 'business');
    });

    test('builds Google Flights URI with readable flight query', () {
      final uri = service.googleFlightsUri(request);

      expect(uri.host, 'www.google.com');
      expect(uri.path, '/travel/flights');
      expect(uri.queryParameters['q'], contains('JFK to LAX'));
      expect(uri.queryParameters['q'], contains('2026-07-04'));
      expect(uri.queryParameters['q'], contains('2 passengers'));
      expect(uri.queryParameters['q'], contains('Business'));
    });

    test('builds Kayak URI with route path and cabin filter', () {
      final uri = service.kayakUri(request);

      expect(uri.host, 'www.kayak.com');
      expect(uri.path, '/flights/JFK-LAX/2026-07-04');
      expect(uri.queryParameters['sort'], 'bestflight_a');
      expect(uri.queryParameters['fs'], 'cabin=b');
      expect(uri.queryParameters['ucs'], '2');
    });

    test('routes provider enum to matching URI builder', () {
      final uri = service.uriForProvider(
        BookingProvider.googleFlights,
        request,
      );

      expect(uri.host, 'www.google.com');
      expect(uri.path, '/travel/flights');
    });

    test('maps stored provider values and falls back to Skyscanner', () {
      expect(BookingProvider.fromStorageValue('kayak'), BookingProvider.kayak);
      expect(
        BookingProvider.fromStorageValue('missing'),
        BookingProvider.skyscanner,
      );
      expect(
        BookingProvider.fromStorageValue(null),
        BookingProvider.skyscanner,
      );
    });

    test('builds known airline direct URI when airline code is provided', () {
      final uri = service.airlineDirectUri(
        BookingSearchRequest(
          origin: 'JFK',
          destination: 'LAX',
          departureDate: DateTime(2026, 7, 4),
          passengers: 1,
          cabinClass: CabinClass.economy,
          airlineCode: 'AA',
        ),
      );

      expect(uri.host, 'www.aa.com');
      expect(uri.queryParameters['from'], 'JFK');
      expect(uri.queryParameters['to'], 'LAX');
      expect(uri.queryParameters['depart'], '2026-07-04');
      expect(uri.queryParameters['adults'], '1');
    });
  });
}
