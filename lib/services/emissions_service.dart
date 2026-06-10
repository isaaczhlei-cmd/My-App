import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../screens/book_flight/airport_directory.dart';

class EmissionsService {
  @visibleForTesting
  static String debugScrub(String input, String apiKey) {
    if (apiKey.trim().isEmpty) return input;
    return input.replaceAll(apiKey, '[REDACTED]');
  }

  EmissionsService({
    http.Client? client,
    String? apiKey,
    String baseUrl = _defaultBaseUrl,
  }) : _client = client,
       _apiKeyOverride = apiKey,
       _baseUrl = baseUrl;

  static const String _defaultBaseUrl =
      'https://travelimpactmodel.googleapis.com/v1';

  final http.Client? _client;
  final String? _apiKeyOverride;
  final String _baseUrl;

  String get _apiKey {
    if (_apiKeyOverride != null) return _apiKeyOverride;
    return dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_apiKey.isNotEmpty) 'X-Goog-Api-Key': _apiKey,
    };
  }

  Future<http.Response> _post(Uri url, Map<String, Object?> body) {
    final encodedBody = jsonEncode(body);
    final client = _client;
    if (client != null) {
      return client.post(url, headers: _headers, body: encodedBody);
    }
    return http.post(url, headers: _headers, body: encodedBody);
  }

  /// Compute emissions for a specific flight
  /// Returns emissions in kg CO2 per passenger
  Future<FlightEmissionsResult?> computeFlightEmissions({
    required String origin,
    required String destination,
    required String operatingCarrierCode,
    required int flightNumber,
    required DateTime departureDate,
  }) async {
    final url = Uri.parse('$_baseUrl/flights:computeFlightEmissions');

    final body = <String, Object?>{
      'flights': [
        {
          'origin': origin.toUpperCase(),
          'destination': destination.toUpperCase(),
          'operatingCarrierCode': operatingCarrierCode.toUpperCase(),
          'flightNumber': flightNumber,
          'departureDate': {
            'year': departureDate.year,
            'month': departureDate.month,
            'day': departureDate.day,
          },
        },
      ],
    };

    try {
      final response = await _post(url, body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FlightEmissionsResult.fromJson(data);
      } else {
        debugPrint('[TIM] computeFlightEmissions ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[TIM] computeFlightEmissions error: $e');
      return null;
    }
  }

  /// Compute typical emissions between two airports
  /// Useful when specific flight details aren't available
  Future<TypicalEmissionsResult?> computeTypicalEmissions({
    required String origin,
    required String destination,
  }) async {
    final url = Uri.parse('$_baseUrl/flights:computeTypicalFlightEmissions');

    final body = <String, Object?>{
      'routes': [
        {
          'origin': origin.toUpperCase(),
          'destination': destination.toUpperCase(),
        },
      ],
    };

    try {
      final response = await _post(url, body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TypicalEmissionsResult.fromJson(data);
      } else {
        debugPrint('[TIM] computeTypicalEmissions ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[TIM] computeTypicalEmissions error: $e');
      return null;
    }
  }

  /// Haversine-based local fallback. Returns economy kg CO2/pax.
  /// Uses DEFRA 2024 emission factors with radiative forcing included.
  double? computeLocalEmissions({
    required String origin,
    required String destination,
  }) {
    final orig = AirportDirectory.airports.where(
      (a) => a.code.toUpperCase() == origin.toUpperCase(),
    ).firstOrNull;
    final dest = AirportDirectory.airports.where(
      (a) => a.code.toUpperCase() == destination.toUpperCase(),
    ).firstOrNull;

    if (orig == null || dest == null) return null;

    final distKm = _haversineKm(orig.latitude, orig.longitude, dest.latitude, dest.longitude);
    // DEFRA 2024: short-haul <1500 km = 0.255 kg/km, long-haul = 0.195 kg/km (economy, incl. RFI)
    final factor = distKm < 1500 ? 0.255 : 0.195;
    return distKm * factor;
  }

  static double cabinMultiplier(CabinClass cabin) => switch (cabin) {
    CabinClass.economy => 1.0,
    CabinClass.premiumEconomy => 1.6,
    CabinClass.business => 2.8,
    CabinClass.first => 4.0,
  };

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}

/// Result from computeFlightEmissions endpoint
class FlightEmissionsResult {
  final List<FlightEmission> flightEmissions;
  final String? modelVersion;

  FlightEmissionsResult({required this.flightEmissions, this.modelVersion});

  factory FlightEmissionsResult.fromJson(Map<String, dynamic> json) {
    final emissions =
        (json['flightEmissions'] as List?)
            ?.map((e) => FlightEmission.fromJson(e))
            .toList() ??
        [];
    return FlightEmissionsResult(
      flightEmissions: emissions,
      modelVersion: json['modelVersion']?['dated'],
    );
  }
}

class FlightEmission {
  final FlightInfo? flight;
  final EmissionsByClass? emissionsGramsPerPax;

  FlightEmission({this.flight, this.emissionsGramsPerPax});

  factory FlightEmission.fromJson(Map<String, dynamic> json) {
    return FlightEmission(
      flight: json['flight'] != null
          ? FlightInfo.fromJson(json['flight'])
          : null,
      emissionsGramsPerPax: json['emissionsGramsPerPax'] != null
          ? EmissionsByClass.fromJson(json['emissionsGramsPerPax'])
          : null,
    );
  }

  /// Get emissions in kg for a specific cabin class
  double getEmissionsKg(CabinClass cabinClass) {
    if (emissionsGramsPerPax == null) return 0;
    final grams = switch (cabinClass) {
      CabinClass.economy => emissionsGramsPerPax!.economy,
      CabinClass.premiumEconomy => emissionsGramsPerPax!.premiumEconomy,
      CabinClass.business => emissionsGramsPerPax!.business,
      CabinClass.first => emissionsGramsPerPax!.first,
    };
    return (grams ?? 0) / 1000; // Convert grams to kg
  }
}

class FlightInfo {
  final String? origin;
  final String? destination;
  final String? operatingCarrierCode;
  final int? flightNumber;
  final DateTime? departureDate;

  FlightInfo({
    this.origin,
    this.destination,
    this.operatingCarrierCode,
    this.flightNumber,
    this.departureDate,
  });

  factory FlightInfo.fromJson(Map<String, dynamic> data) {
    DateTime? departureDate;
    final dateMap = data['departureDate'] as Map<String, dynamic>?;
    if (dateMap != null) {
      departureDate = DateTime(
        dateMap['year'],
        dateMap['month'],
        dateMap['day'],
      );
    }

    return FlightInfo(
      origin: data['origin'],
      destination: data['destination'],
      operatingCarrierCode: data['operatingCarrierCode'],
      flightNumber: data['flightNumber'],
      departureDate: departureDate,
    );
  }
}

class EmissionsByClass {
  final int? economy;
  final int? premiumEconomy;
  final int? business;
  final int? first;

  EmissionsByClass({
    this.economy,
    this.premiumEconomy,
    this.business,
    this.first,
  });

  factory EmissionsByClass.fromJson(Map<String, dynamic> json) {
    return EmissionsByClass(
      economy: json['economy'],
      premiumEconomy: json['premiumEconomy'],
      business: json['business'],
      first: json['first'],
    );
  }
}

/// Result from computeTypicalFlightEmissions endpoint
class TypicalEmissionsResult {
  final List<TypicalRouteEmission> typicalEmissions;

  TypicalEmissionsResult({required this.typicalEmissions});

  factory TypicalEmissionsResult.fromJson(Map<String, dynamic> json) {
    final emissions =
        (json['typicalFlightEmissions'] as List?)
            ?.map((e) => TypicalRouteEmission.fromJson(e))
            .toList() ??
        [];
    return TypicalEmissionsResult(typicalEmissions: emissions);
  }
}

class TypicalRouteEmission {
  final String? origin;
  final String? destination;
  final EmissionsByClass? emissionsGramsPerPax;

  TypicalRouteEmission({
    this.origin,
    this.destination,
    this.emissionsGramsPerPax,
  });

  factory TypicalRouteEmission.fromJson(Map<String, dynamic> json) {
    return TypicalRouteEmission(
      origin: json['route']?['origin'],
      destination: json['route']?['destination'],
      emissionsGramsPerPax: json['emissionsGramsPerPax'] != null
          ? EmissionsByClass.fromJson(json['emissionsGramsPerPax'])
          : null,
    );
  }

  /// Get emissions in kg for a specific cabin class
  double getEmissionsKg(CabinClass cabinClass) {
    if (emissionsGramsPerPax == null) return 0;
    final grams = switch (cabinClass) {
      CabinClass.economy => emissionsGramsPerPax!.economy,
      CabinClass.premiumEconomy => emissionsGramsPerPax!.premiumEconomy,
      CabinClass.business => emissionsGramsPerPax!.business,
      CabinClass.first => emissionsGramsPerPax!.first,
    };
    return (grams ?? 0) / 1000;
  }
}

enum CabinClass { economy, premiumEconomy, business, first }

extension CabinClassExtension on CabinClass {
  String get displayName {
    return switch (this) {
      CabinClass.economy => 'Economy',
      CabinClass.premiumEconomy => 'Premium Economy',
      CabinClass.business => 'Business',
      CabinClass.first => 'First',
    };
  }
}
