import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/flight.dart';

class FlightLogException implements Exception {
  const FlightLogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirestoreService {
  static const _writeTimeout = Duration(seconds: 15);

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _flightsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('flights');
  }

  /// Add a flight to the current user's collection
  Future<void> addFlight(Flight flight) async {
    final uid = _uid;
    if (uid == null) {
      throw const FlightLogException('Sign in to save flights to your log.');
    }

    try {
      await _flightsRef(uid).add(flight.toFirestore()).timeout(_writeTimeout);
    } on TimeoutException {
      throw const FlightLogException(
        'Saving is taking too long. Check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      throw FlightLogException(_flightLogErrorMessage(e));
    }
  }

  /// Stream all flights for the current user, ordered by date descending
  Stream<List<Flight>> getFlightsStream() async* {
    final uid = _uid;
    if (uid == null) {
      yield const <Flight>[];
      return;
    }

    try {
      yield* _flightsRef(
        uid,
      ).orderBy('date', descending: true).snapshots().map(_flightsFromSnapshot);
    } catch (e, st) {
      debugPrint('Flight log stream failed: $e');
      debugPrintStack(stackTrace: st);
      yield const <Flight>[];
    }
  }

  /// Get all flights once (not a stream)
  Future<List<Flight>> getFlights() async {
    final uid = _uid;
    if (uid == null) return [];
    final snapshot = await _flightsRef(
      uid,
    ).orderBy('date', descending: true).get();
    return _flightsFromSnapshot(snapshot);
  }

  /// Delete a flight by ID
  Future<void> deleteFlight(String flightId) async {
    final uid = _uid;
    if (uid == null) return;
    if (_auth.currentUser?.isAnonymous == true) return;
    await _flightsRef(uid).doc(flightId).delete();
  }

  /// Delete all data owned by [uid]: flights subcollection then profile doc.
  Future<void> deleteUserData(String uid) => UserDataDeletionCoordinator(
    FirestoreUserDataStore(_firestore),
  ).deleteUserData(uid);

  String _flightLogErrorMessage(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Firebase rejected this save. Sign in again or check Firestore rules.';
    }
    if (e.code == 'unavailable') {
      return 'Flight log is unavailable right now. Check your connection and try again.';
    }
    return 'Could not save this flight. Please try again.';
  }

  List<Flight> _flightsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final flights = <Flight>[];
    for (final doc in snapshot.docs) {
      try {
        flights.add(Flight.fromFirestore(doc));
      } catch (e, st) {
        debugPrint('Skipping unreadable flight ${doc.id}: $e');
        debugPrintStack(stackTrace: st);
      }
    }
    return flights;
  }
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
