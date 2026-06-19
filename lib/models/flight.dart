// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

class Flight {
  final String id;
  final String originCode;
  final String destinationCode;
  final DateTime date;
  final String travelClass; // economy, premium encomnemy, business, first
  final double emissionsKg;
  final DateTime createdAt;
  final String AirlineCode;
  final String AirlineNumber;

  Flight({
    required this.id,
    required this.originCode,
    required this.destinationCode,
    required this.date,
    required this.travelClass,
    required this.emissionsKg,
    required this.createdAt,
    this.AirlineCode = "",
    this.AirlineNumber = "",
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'originCode': originCode,
      'destinationCode': destinationCode,
      'date': Timestamp.fromDate(date),
      'travelClass': travelClass,
      'emissionsKg': emissionsKg,
      'createdAt': Timestamp.fromDate(createdAt),
      'airlineCode': AirlineCode,
      'airlineNumber': AirlineNumber,
    };
  }

  /// Create from Firestore document
  factory Flight.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Flight.fromMap(id: doc.id, data: data);
  }

  factory Flight.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTimeFromFirestore(data['createdAt']);
    return Flight(
      id: id,
      originCode: data['originCode'] ?? '',
      destinationCode: data['destinationCode'] ?? '',
      date: _dateTimeFromFirestore(data['date'], fallback: createdAt),
      travelClass: data['travelClass'] ?? 'economy',
      emissionsKg: _doubleFromFirestore(data['emissionsKg']),
      createdAt: createdAt,
      AirlineCode: data['airlineCode'] ?? '',
      AirlineNumber: data['airlineNumber'] ?? '',
    );
  }

  static DateTime _dateTimeFromFirestore(Object? value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }

  static double _doubleFromFirestore(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
