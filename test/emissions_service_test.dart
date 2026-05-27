import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/services/emissions_service.dart';

void main() {
  group('EmissionsService', () {
    test(
      'sends Travel Impact Model key in header for specific flights',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://travelimpactmodel.googleapis.com/v1/flights:computeFlightEmissions',
          );
          expect(request.url.queryParameters, isNot(contains('key')));
          expect(request.headers['X-Goog-Api-Key'], 'test-key');
          expect(request.headers['Content-Type'], 'application/json');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final flight =
              (body['flights'] as List<dynamic>).single as Map<String, dynamic>;
          expect(flight['origin'], 'JFK');
          expect(flight['destination'], 'LAX');
          expect(flight['operatingCarrierCode'], 'AA');
          expect(flight['flightNumber'], 100);

          return http.Response(
            jsonEncode({
              'flightEmissions': [
                {
                  'flight': {
                    'origin': 'JFK',
                    'destination': 'LAX',
                    'operatingCarrierCode': 'AA',
                    'flightNumber': 100,
                    'departureDate': {'year': 2026, 'month': 9, 'day': 1},
                  },
                  'emissionsGramsPerPax': {'economy': 140000},
                },
              ],
            }),
            200,
          );
        });

        final service = EmissionsService(client: client, apiKey: 'test-key');
        final result = await service.computeFlightEmissions(
          origin: 'jfk',
          destination: 'lax',
          operatingCarrierCode: 'aa',
          flightNumber: 100,
          departureDate: DateTime(2026, 9, 1),
        );

        expect(result, isNotNull);
        expect(
          result!.flightEmissions.single.getEmissionsKg(CabinClass.economy),
          140,
        );
      },
    );

    test(
      'sends Travel Impact Model key in header for typical route requests',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://travelimpactmodel.googleapis.com/v1/flights:computeTypicalFlightEmissions',
          );
          expect(request.url.queryParameters, isNot(contains('key')));
          expect(request.headers['X-Goog-Api-Key'], 'test-key');

          return http.Response(
            jsonEncode({
              'typicalFlightEmissions': [
                {
                  'route': {'origin': 'SFO', 'destination': 'SEA'},
                  'emissionsGramsPerPax': {'economy': 90000},
                },
              ],
            }),
            200,
          );
        });

        final service = EmissionsService(client: client, apiKey: 'test-key');
        final result = await service.computeTypicalEmissions(
          origin: 'sfo',
          destination: 'sea',
        );

        expect(result, isNotNull);
        expect(
          result!.typicalEmissions.single.getEmissionsKg(CabinClass.economy),
          90,
        );
      },
    );
  });
}
