import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/screens/add_flight/flight_catalog.dart';
import 'package:flightprint/services/emissions_service.dart';

void main() {
  group('FlightCatalogEntry cabin capacities', () {
    test(
      'returns selected cabin capacities and zero for unavailable cabins',
      () {
        final jetBlueJfkLax = FlightCatalog.entries.firstWhere(
          (entry) =>
              entry.carrierCode == 'B6' &&
              entry.flightNumber == 23 &&
              entry.originCode == 'JFK' &&
              entry.destinationCode == 'LAX',
        );

        expect(jetBlueJfkLax.aircraftType, 'Airbus A321neo');
        expect(jetBlueJfkLax.capacityFor(CabinClass.economy), 200);
        expect(jetBlueJfkLax.capacityFor(CabinClass.business), 0);
        expect(jetBlueJfkLax.capacityFor(CabinClass.first), 0);
      },
    );

    test(
      'every catalog entry has an aircraft and at least one valid cabin',
      () {
        for (final entry in FlightCatalog.entries) {
          expect(
            entry.aircraftType.trim(),
            isNotEmpty,
            reason: '${entry.compactFlightCode} needs an aircraft type.',
          );
          expect(
            CabinClass.values.any((cabin) => entry.capacityFor(cabin) > 0),
            isTrue,
            reason: '${entry.compactFlightCode} needs at least one cabin.',
          );
        }
      },
    );
  });
}
