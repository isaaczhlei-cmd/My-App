import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/models/flight.dart';

void main() {
  group('Flight.fromMap', () {
    test('accepts older partial flight records without throwing', () {
      final flight = Flight.fromMap(
        id: 'flight-1',
        data: {
          'originCode': 'JFK',
          'destinationCode': 'DOH',
          'date': '2026-06-18T00:00:00.000',
          'emissionsKg': '2100.5',
          'airlineCode': 'QR',
          'airlineNumber': '744',
        },
      );

      expect(flight.id, 'flight-1');
      expect(flight.originCode, 'JFK');
      expect(flight.destinationCode, 'DOH');
      expect(flight.date, DateTime(2026, 6, 18));
      expect(flight.emissionsKg, 2100.5);
      expect(flight.createdAt, isA<DateTime>());
      expect(flight.AirlineCode, 'QR');
      expect(flight.AirlineNumber, '744');
    });
  });
}
