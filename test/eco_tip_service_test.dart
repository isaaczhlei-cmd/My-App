import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_app/services/eco_tip_service.dart';

void main() {
  group('EcoTipService', () {
    test('has a large unique fallback tip bank', () {
      final normalizedTips = EcoTipService.fallbackTips
          .map(
            (tip) =>
                tip.tip.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
          )
          .toSet();

      expect(EcoTipService.fallbackTips.length, greaterThanOrEqualTo(200));
      expect(normalizedTips.length, EcoTipService.fallbackTips.length);
    });

    test('parses a structured OpenAI response', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.openai.com/v1/responses');
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-5-mini');
        expect(body['text']['format']['type'], 'json_schema');
        final systemPrompt = body['input'][0]['content'][0]['text'] as String;
        expect(systemPrompt, contains('aircraft type'));
        expect(systemPrompt, contains('connection hubs'));
        expect(systemPrompt, contains('less-obvious'));

        return http.Response(
          jsonEncode({
            'output_text': jsonEncode({
              'tip': 'Take the train for short regional trips.',
              'category': 'travel',
            }),
          }),
          200,
        );
      });

      final service = EcoTipService(client: client, apiKey: 'test-key');
      final tip = await service.fetchEcoTip(
        flightCount: 3,
        totalEmissionsKg: 120.5,
        recentTravelPattern: 'Recent routes: JFK -> LAX.',
      );

      expect(tip.tip, 'Take the train for short regional trips.');
      expect(tip.category, 'travel');
      service.dispose();
    });

    test('falls back when the response is malformed', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'output_text': 'not valid json'}),
          200,
        );
      });

      final service = EcoTipService(client: client, apiKey: 'test-key');
      final tip = await service.fetchEcoTip(
        flightCount: 1,
        totalEmissionsKg: 44.0,
        recentTravelPattern: 'Recent routes: SFO -> SEA.',
      );

      expect(
        EcoTipService.fallbackTips.any((fallback) => fallback.tip == tip.tip),
        isTrue,
      );
      expect(tip.category, isNotEmpty);
      service.dispose();
    });
  });
}
