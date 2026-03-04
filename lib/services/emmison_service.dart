import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EmmisonService {
  static String get API_KEY => dotenv.env["API_KEY"] ?? "";
  static String BASE_URL = 'https://travelimpactmodel.googleapis.com/v1';

  Future<FlightEmissonsResult?> computeFlightEmssions({
    required String origin,
    required String destination,
    required String operatingCarrierCode,
    required int flightnumber,
    required DateTime departureDate,
  }) async {
    final url = Uri.parse(
      '$BASE_URL/flights:computeFlightEmissions?key=$API_KEY',
    );

    final body = {
      'flights': [
        {
          'origin': origin.toUpperCase(),
          'destination': destination.toUpperCase(),
          'operatingCarrierCode': operatingCarrierCode.toUpperCase(),
          'flightNumber': flightnumber,
          'departureDate': {
            'year': departureDate.year,
            'month': departureDate.month,
            'day': departureDate.day,
          },
        },
      ],
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FlightEmissonsResult.fromJson(data);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error computing flight emissions: $e');
      return null;
    }
  }

  /// Compute typical emissions between two airports
  /// Useful when specific flight details aren't available
  Future<TypicalEmissionsResult?> computeTypicalEmissions({
    required String origin,
    required String destination,
  }) async {
    final url = Uri.parse(
      '$BASE_URL/flights:computeTypicalFlightEmissions?key=$API_KEY',
    );

    final body = {
      'routes': [
        {
          'origin': origin.toUpperCase(),
          'destination': destination.toUpperCase(),
        },
      ],
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TypicalEmissionsResult.fromJson(data);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error computing typical emissions: $e');
      return null;
    }
  }
}

class FlightEmissonsResult {
  final List<FlightEmission> flightEmissionsList;
  final String? modelVersion;

  FlightEmissonsResult({required this.flightEmissionsList, this.modelVersion});

  factory FlightEmissonsResult.fromJson(Map<String, dynamic> json) {
    final emissions =
        (json['flightEmissions'] as List?)
            ?.map((e) => FlightEmission.fromJson(e))
            .toList() ??
        [];
    return FlightEmissonsResult(
      flightEmissionsList: emissions,
      modelVersion: json['modelVersion']?['dated'],
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

  double emissionConvertToKg(CabinClass cabinclass) {
    if (emissionsGramsPerPax == null) return 0;
    final grams = switch (cabinclass) {
      CabinClass.economy => emissionsGramsPerPax!.economy,
      CabinClass.premiumEconomy => emissionsGramsPerPax!.premiumEconomy,
      CabinClass.business => emissionsGramsPerPax!.business,
      CabinClass.first => emissionsGramsPerPax!.first,
    };
    return (grams ?? 0) / 1000;
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
  factory FlightInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Map<String, dynamic>? dateMap) {
      if (dateMap == null) return null;
      return DateTime(dateMap['year'], dateMap['month'], dateMap['day']);
    }

    return FlightInfo(
      origin: json['origin'],
      destination: json['destination'],
      operatingCarrierCode: json['operatingCarrierCode'],
      flightNumber: json['flightNumber'],
      departureDate: parseDate(json['departureDate'] as Map<String, dynamic>?),
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

enum CabinClass {
  economy, // 0
  premiumEconomy, // 1
  business, // 2
  first, // 3
}

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
