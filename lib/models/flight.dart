import 'package:cloud_firestore/cloud_firestore.dart';

class Flight {
  final String id;
  final String originCode;
  final String destinationCode;
  final DateTime date;
  final String travelClass; // economy, business, first
  final double emissionsKg;
  final DateTime createdAt;

  Flight({
    required this.id,
    required this.originCode,
    required this.destinationCode,
    required this.date,
    required this.travelClass,
    required this.emissionsKg,
    required this.createdAt,
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
    );
  }
}
