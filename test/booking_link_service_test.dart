import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/services/booking_link_service.dart';
import 'package:my_app/services/emissions_service.dart';

void main() {
  group('BookingLinkService', () {
    group('skyscannerUri', () {
      test('builds correct Skyscanner URL for economy class', () {
        final uri = BookingLinkService.skyscannerUri(
          origin: 'JFK',
          destination: 'LAX',
          departureDate: DateTime(2026, 6, 15),
          passengers: 1,
          cabinClass: CabinClass.economy,
        );

        expect(uri.host, 'www.skyscanner.net');
        expect(uri.path, '/g/referrals/v1/flights/day-view/');
        expect(uri.queryParameters['origin'], 'JFK');
        expect(uri.queryParameters['destination'], 'LAX');
        expect(uri.queryParameters['outboundDate'], '2026-06-15');
        expect(uri.queryParameters['adultsv2'], '1');
        expect(uri.queryParameters['cabinclass'], 'economy');
        expect(uri.queryParameters['market'], 'US');
        expect(uri.queryParameters['locale'], 'en-US');
        expect(uri.queryParameters['currency'], 'USD');
      });

      test('builds correct Skyscanner URL with multiple passengers', () {
        final uri = BookingLinkService.skyscannerUri(
          origin: 'LHR',
          destination: 'CDG',
          departureDate: DateTime(2026, 12, 25),
          passengers: 4,
          cabinClass: CabinClass.business,
        );

        expect(uri.queryParameters['origin'], 'LHR');
        expect(uri.queryParameters['destination'], 'CDG');
        expect(uri.queryParameters['outboundDate'], '2026-12-25');
        expect(uri.queryParameters['adultsv2'], '4');
        expect(uri.queryParameters['cabinclass'], 'business');
      });

      test('converts CabinClass to correct Skyscanner cabin class values', () {
        final testCases = {
          CabinClass.economy: 'economy',
          CabinClass.premiumEconomy: 'premiumeconomy',
          CabinClass.business: 'business',
          CabinClass.first: 'first',
        };

        for (final entry in testCases.entries) {
          final uri = BookingLinkService.skyscannerUri(
            origin: 'JFK',
            destination: 'LAX',
            departureDate: DateTime(2026, 6, 15),
            passengers: 1,
            cabinClass: entry.key,
          );
          expect(uri.queryParameters['cabinclass'], entry.value);
        }
      });

      test('formats dates correctly (zero-padded)', () {
        final uri = BookingLinkService.skyscannerUri(
          origin: 'JFK',
          destination: 'LAX',
          departureDate: DateTime(2026, 1, 5),
          passengers: 1,
          cabinClass: CabinClass.economy,
        );

        expect(uri.queryParameters['outboundDate'], '2026-01-05');
      });
    });

    group('googleFlightsUri', () {
      test('builds correct Google Flights URL for economy class', () {
        final uri = BookingLinkService.googleFlightsUri(
          origin: 'JFK',
          destination: 'LAX',
          departureDate: DateTime(2026, 6, 15),
          passengers: 1,
          cabinClass: CabinClass.economy,
        );

        expect(uri.host, 'www.google.com');
        expect(uri.path, '/travel/flights');
        expect(uri.queryParameters['q'], contains('JFK'));
        expect(uri.queryParameters['q'], contains('LAX'));
        expect(uri.queryParameters['q'], contains('2026-06-15'));
        expect(uri.queryParameters['q'], contains('1x'));
      });

      test('builds correct Google Flights URL with multiple passengers', () {
        final uri = BookingLinkService.googleFlightsUri(
          origin: 'ORD',
          destination: 'MIA',
          departureDate: DateTime(2026, 3, 20),
          passengers: 2,
          cabinClass: CabinClass.premiumEconomy,
        );

        final query = uri.queryParameters['q']!;
        expect(query, contains('ORD'));
        expect(query, contains('MIA'));
        expect(query, contains('2026-03-20'));
        expect(query, contains('2x'));
      });

      test(
        'converts CabinClass to correct Google Flights cabin class values',
        () {
          final testCases = {
            CabinClass.economy: 'economy',
            CabinClass.premiumEconomy: 'premium',
            CabinClass.business: 'business',
            CabinClass.first: 'first',
          };

          for (final entry in testCases.entries) {
            final uri = BookingLinkService.googleFlightsUri(
              origin: 'JFK',
              destination: 'LAX',
              departureDate: DateTime(2026, 6, 15),
              passengers: 1,
              cabinClass: entry.key,
            );
            final query = uri.queryParameters['q']!;
            expect(query, contains('1x${entry.value}'));
          }
        },
      );

      test('formats dates correctly in query string', () {
        final uri = BookingLinkService.googleFlightsUri(
          origin: 'LAX',
          destination: 'SFO',
          departureDate: DateTime(2026, 7, 4),
          passengers: 1,
          cabinClass: CabinClass.economy,
        );

        expect(uri.queryParameters['q'], contains('2026-07-04'));
      });
    });

    group('kayakUri', () {
      test('builds correct Kayak URL for economy class', () {
        final uri = BookingLinkService.kayakUri(
          origin: 'JFK',
          destination: 'LAX',
          departureDate: DateTime(2026, 6, 15),
          passengers: 1,
          cabinClass: CabinClass.economy,
        );

        expect(uri.host, 'www.kayak.com');
        expect(uri.path, '/flights/JFK-LAX/2026-06-15/1/e');
      });

      test('builds correct Kayak URL with multiple passengers', () {
        final uri = BookingLinkService.kayakUri(
          origin: 'SFO',
          destination: 'NYC',
          departureDate: DateTime(2026, 9, 10),
          passengers: 3,
          cabinClass: CabinClass.business,
        );

        expect(uri.path, '/flights/SFO-NYC/2026-09-10/3/b');
      });

      test('converts CabinClass to correct Kayak cabin class values', () {
        final testCases = {
          CabinClass.economy: 'e',
          CabinClass.premiumEconomy: 'pe',
          CabinClass.business: 'b',
          CabinClass.first: 'f',
        };

        for (final entry in testCases.entries) {
          final uri = BookingLinkService.kayakUri(
            origin: 'JFK',
            destination: 'LAX',
            departureDate: DateTime(2026, 6, 15),
            passengers: 1,
            cabinClass: entry.key,
          );
          expect(uri.path.endsWith('/${entry.value}'), true);
        }
      });

      test('formats dates correctly in path (zero-padded)', () {
        final uri = BookingLinkService.kayakUri(
          origin: 'BOS',
          destination: 'MIA',
          departureDate: DateTime(2026, 1, 8),
          passengers: 2,
          cabinClass: CabinClass.economy,
        );

        expect(uri.path, '/flights/BOS-MIA/2026-01-08/2/e');
      });
    });

    group('cross-provider consistency', () {
      test('all providers handle same route correctly', () {
        const origin = 'ORD';
        const destination = 'LAX';
        final date = DateTime(2026, 8, 1);
        const passengers = 2;
        const cabin = CabinClass.business;

        final skyscanner = BookingLinkService.skyscannerUri(
          origin: origin,
          destination: destination,
          departureDate: date,
          passengers: passengers,
          cabinClass: cabin,
        );

        final google = BookingLinkService.googleFlightsUri(
          origin: origin,
          destination: destination,
          departureDate: date,
          passengers: passengers,
          cabinClass: cabin,
        );

        final kayak = BookingLinkService.kayakUri(
          origin: origin,
          destination: destination,
          departureDate: date,
          passengers: passengers,
          cabinClass: cabin,
        );

        // All should be valid URIs
        expect(skyscanner.isAbsolute, true);
        expect(google.isAbsolute, true);
        expect(kayak.isAbsolute, true);

        // Each provider uses different host
        expect(skyscanner.host, 'www.skyscanner.net');
        expect(google.host, 'www.google.com');
        expect(kayak.host, 'www.kayak.com');
      });
    });
  });
}
