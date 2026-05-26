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
    return Flight(
      id: doc.id,
      originCode: data['originCode'] ?? '',
      destinationCode: data['destinationCode'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      travelClass: data['travelClass'] ?? 'economy',
      emissionsKg: (data['emissionsKg'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      AirlineCode: data['airlineCode'] ?? '',
      AirlineNumber: data['airlineNumber'] ?? '',
    );
  }
}
