import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/models/flight.dart';

class EmmisonService {
  static String get API_KEY => dotenv.env["API_KEY"] ?? "";
  static String BASE_URL = 'https://travelimpactmodel.googleapis.com/v1';
}

class FlightEmissonsResult {
  final List<FlightEmission> flightEmissionsList;
  final String? modelVersion;

  FlightEmissonsResult({required this.flightEmissionsList, this.modelVersion});

  factory FlightEmissonsResult.fromJson(Map<String, dynamic> json) {
     final emissions = (json['flightEmissions'] as List?)
            ?.map((e) => FlightEmission.fromJson(e))
            .toList() ??
        [];
    return FlightEmissonsResult(
      flightEmissionsList: emissions,
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
