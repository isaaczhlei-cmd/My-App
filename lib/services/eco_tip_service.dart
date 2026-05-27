import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EcoTipSuggestion {
  final String tip;
  final String category;

  const EcoTipSuggestion({
    required this.tip,
    required this.category,
  });
}

class EcoTipService {
  @visibleForTesting
  static String debugScrub(String input, String apiKey) {
    if (apiKey.trim().isEmpty) return input;
    return input.replaceAll(apiKey, '[REDACTED]');
  }

  static const String _model = 'gpt-5-mini';
  static const String _baseUrl = 'https://api.openai.com/v1/responses';
  static const List<String> _categories = <String>[
    'travel',
    'home',
    'energy',
    'waste',
    'shopping',
    'general',
  ];

  static const List<EcoTipSuggestion> fallbackTips = <EcoTipSuggestion>[
    EcoTipSuggestion(
      tip: 'Compare aircraft type and seat count, not just stops, when two fares are similar.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'A slightly longer route can still be cleaner if it uses a newer, denser aircraft.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'If you need a connection, compare hubs because some layovers add a big detour.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'For the same price, pick the itinerary with fewer premium seats or a smaller cabin footprint.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Use flexible dates to unlock a direct flight that is missing on your original day.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'When you must connect, avoid routes that backtrack through a faraway hub.',
      category: 'travel',
    ),
  ];

  final http.Client _client;
  final String? _apiKeyOverride;
  final bool _ownsClient;

  EcoTipService({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey,
        _ownsClient = client == null;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<EcoTipSuggestion> fetchEcoTip({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
    int refreshToken = 0,
  }) async {
    final apiKey = _apiKeyOverride ?? dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.trim().isEmpty) {
      return pickFallbackTip(
        flightCount: flightCount,
        totalEmissionsKg: totalEmissionsKg,
        recentTravelPattern: recentTravelPattern,
        refreshToken: refreshToken,
      );
    }

    final requestBody = _buildRequestBody(
      flightCount: flightCount,
      totalEmissionsKg: totalEmissionsKg,
      recentTravelPattern: recentTravelPattern,
      refreshToken: refreshToken,
    );

    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final outputText = _extractOutputText(decoded)?.trim();
      if (outputText == null || outputText.isEmpty) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final parsed = jsonDecode(outputText);
      if (parsed is! Map<String, dynamic>) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final tip = (parsed['tip'] as String?)?.trim();
      if (tip == null || tip.isEmpty) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final category = _normalizeCategory(parsed['category'] as String?);
      return EcoTipSuggestion(tip: tip, category: category);
    } catch (_) {
      return pickFallbackTip(
        flightCount: flightCount,
        totalEmissionsKg: totalEmissionsKg,
        recentTravelPattern: recentTravelPattern,
        refreshToken: refreshToken,
      );
    }
  }

  static EcoTipSuggestion pickFallbackTip({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
    int refreshToken = 0,
  }) {
    final seed = flightCount * 7 +
        totalEmissionsKg.round() +
        recentTravelPattern.runes.fold<int>(0, (sum, rune) => sum + rune) +
        refreshToken * 13;
    final index = seed.abs() % fallbackTips.length;
    return fallbackTips[index];
  }

  Map<String, dynamic> _buildRequestBody({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
    required int refreshToken,
  }) {
    return {
      'model': _model,
      'input': [
        {
          'role': 'system',
          'content': [
            {
              'type': 'input_text',
              'text':
                  'You write one short, practical eco tip for a flight carbon tracker app. '
                  'Focus on real flight-planning tradeoffs like aircraft type, cabin layout, connection hubs, '
                  'seat density, route detours, and flexible dates. '
                  'Do not give generic sustainability advice or obvious tips unless they are directly justified by the trip. '
                  'Prefer concrete, less-obvious, real-world guidance that helps the user choose a better itinerary. '
                  'Return only JSON that matches the schema. Keep the tip to one sentence and under 18 words.',
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': '''
User context:
- Flight count: $flightCount
- Total emissions: ${totalEmissionsKg.toStringAsFixed(1)} kg CO2
- Recent travel pattern: $recentTravelPattern
- Refresh token: $refreshToken

Write one tailored eco tip that helps the user choose a better flight itinerary.
''',
            },
          ],
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'eco_tip',
          'strict': true,
          'description': 'A single short eco tip for the homescreen.',
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'tip': {
                'type': 'string',
                'minLength': 1,
              },
              'category': {
                'type': 'string',
                'enum': _categories,
              },
            },
            'required': ['tip'],
          },
        },
      },
      'max_output_tokens': 80,
    };
  }

  String? _extractOutputText(Map<String, dynamic> decoded) {
    final direct = decoded['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final output = decoded['output'];
    if (output is! List) {
      return null;
    }

    final buffer = StringBuffer();
    for (final item in output) {
      if (item is! Map<String, dynamic>) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map<String, dynamic>) continue;
        if (part['type'] == 'output_text' && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }
    }

    final extracted = buffer.toString();
    return extracted.isEmpty ? null : extracted;
  }

  String _normalizeCategory(String? category) {
    final normalized = (category ?? 'general').trim().toLowerCase();
    if (_categories.contains(normalized)) {
      return normalized;
    }
    return 'general';
  }
}
