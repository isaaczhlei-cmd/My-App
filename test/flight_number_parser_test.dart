import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/services/flight_number_parser.dart';

void main() {
  group('parseFlightNumber', () {
    test('accepts two-letter carrier codes', () {
      final parsed = parseFlightNumber('UA857');

      expect(parsed?.carrier, 'UA');
      expect(parsed?.number, 857);
    });

    test('accepts letter-number carrier codes with or without spaces', () {
      final compact = parseFlightNumber('b623');
      final spaced = parseFlightNumber('B6 23');

      expect(compact?.carrier, 'B6');
      expect(compact?.number, 23);
      expect(spaced?.carrier, 'B6');
      expect(spaced?.number, 23);
    });

    test('rejects invalid carrier codes', () {
      expect(parseFlightNumber('1234'), isNull);
      expect(parseFlightNumber('6B23'), isNull);
    });
  });
}
