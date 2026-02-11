import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EmmisonService {
  static String get API_KEY => dotenv.env["API_KEY"] ?? "";
  static String BASE_URL = 'https://travelimpactmodel.googleapis.com/v1';
}

class FlightEmissonsResult {}

class FlightEmission {}

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
    this.flightNumber, this.departureDate, 
  });
  factory FlightInfo.fromJson(<Map<String, dynamic>>json){
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
