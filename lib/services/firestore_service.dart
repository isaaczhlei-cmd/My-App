import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// Delete all data owned by [uid]: flights subcollection then profile doc.
  Future<void> deleteUserData(String uid) =>
      UserDataDeletionCoordinator(FirestoreUserDataStore(_firestore))
          .deleteUserData(uid);
}

@visibleForTesting
abstract class UserDataStore {
  /// Deletes up to [limit] flight docs in one batch. Returns how many were deleted.
  Future<int> deleteFlightsBatch(String uid, {required int limit});
  Future<void> deleteUserDoc(String uid);
}

@visibleForTesting
class UserDataDeletionCoordinator {
  const UserDataDeletionCoordinator(this._store);

  final UserDataStore _store;

  Future<void> deleteUserData(String uid) async {
    int deleted;
    do {
      deleted = await _store.deleteFlightsBatch(uid, limit: 400);
    } while (deleted == 400);
    await _store.deleteUserDoc(uid);
  }
}

class FirestoreUserDataStore implements UserDataStore {
  const FirestoreUserDataStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<int> deleteFlightsBatch(String uid, {required int limit}) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('flights')
        .limit(limit)
        .get();
    if (snap.docs.isEmpty) return 0;
    final wb = _firestore.batch();
    for (final doc in snap.docs) {
      wb.delete(doc.reference);
    }
    await wb.commit();
    return snap.docs.length;
  }

  @override
  Future<void> deleteUserDoc(String uid) =>
      _firestore.collection('users').doc(uid).delete();
}
