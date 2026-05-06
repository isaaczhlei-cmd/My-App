import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flight.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _flightsRef {
    return _firestore.collection('users').doc(_uid).collection('flights');
  }

  /// Add a flight to the current user's collection
  Future<void> addFlight(Flight flight) async {
    if (_uid == null) return;
    await _flightsRef.add(flight.toFirestore());
  }

  /// Stream all flights for the current user, ordered by date descending
  Stream<List<Flight>> getFlightsStream() {
    if (_uid == null) return Stream.value([]);
    return _flightsRef
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Flight.fromFirestore(doc)).toList());
  }

  /// Get all flights once (not a stream)
  Future<List<Flight>> getFlights() async {
    if (_uid == null) return [];
    final snapshot = await _flightsRef.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => Flight.fromFirestore(doc)).toList();
  }

  /// Delete a flight by ID
  Future<void> deleteFlight(String flightId) async {
    if (_uid == null) return;
    if (_auth.currentUser?.isAnonymous == true) return;
    await _flightsRef.doc(flightId).delete();
  }
}
