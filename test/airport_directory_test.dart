import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/book_flight/airport_directory.dart';

void main() {
  group('AirportDirectory', () {
    test('contains broad IATA airport coverage', () {
      expect(AirportDirectory.airports.length, greaterThanOrEqualTo(500));
      expect(
        AirportDirectory.airports.map((airport) => airport.code).toSet().length,
        AirportDirectory.airports.length,
      );
    });

    test('finds airports by IATA code and ranks exact code first', () {
      final matches = AirportDirectory.search('RDU');

      expect(matches, isNotEmpty);
      expect(matches.first.code, 'RDU');
      expect(matches.first.city, contains('Raleigh'));
    });

    test('finds airports by city outside the old seed list', () {
      final matches = AirportDirectory.search('Portland');

      expect(matches.map((airport) => airport.code), contains('PDX'));
    });

    test('excludes selected counterpart airport from results', () {
      final matches = AirportDirectory.search(
        'San Francisco',
        excludeCode: 'SFO',
      );

      expect(matches.map((airport) => airport.code), isNot(contains('SFO')));
    });

    test('returns null when there is no viable match', () {
      final match = AirportDirectory.findBestMatch('ZZZ unknown airport');

      expect(match, isNull);
    });
  });
}
