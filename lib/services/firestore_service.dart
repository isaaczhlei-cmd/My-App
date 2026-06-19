import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      await _addLocalFlight(uid, flight);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'unavailable') {
        debugPrint('Saving flight locally after Firestore ${e.code}: $e');
        await _addLocalFlight(uid, flight);
        return;
      }
      throw FlightLogException(_flightLogErrorMessage(e));
    }
  }

  /// Stream all flights for the current user, ordered by date descending
  Stream<List<Flight>> getFlightsStream() async* {
    final uid = _uid;
    if (uid == null) {
      yield <Flight>[];
      return;
    }

    final localFlights = await _getLocalFlights(uid);
    yield List<Flight>.of(localFlights);

    try {
      yield* _flightsRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                _mergeFlights(_flightsFromSnapshot(snapshot), localFlights),
          );
    } catch (e, st) {
      debugPrint('Flight log stream failed: $e');
      debugPrintStack(stackTrace: st);
      yield List<Flight>.of(localFlights);
    }
  }

  /// Get all flights once (not a stream)
  Future<List<Flight>> getFlights() async {
    final uid = _uid;
    if (uid == null) return [];
    final localFlights = await _getLocalFlights(uid);
    try {
      final snapshot = await _flightsRef(
        uid,
      ).orderBy('date', descending: true).get();
      return _mergeFlights(_flightsFromSnapshot(snapshot), localFlights);
    } on FirebaseException catch (e) {
      debugPrint('Using local flight history after Firestore ${e.code}: $e');
      return List<Flight>.of(localFlights);
    }
  }

  /// Delete a flight by ID
  Future<void> deleteFlight(String flightId) async {
    final uid = _uid;
    if (uid == null) return;
    if (flightId.startsWith('local-')) {
      await _deleteLocalFlight(uid, flightId);
      return;
    }
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

  String _localFlightsKey(String uid) => 'local_flights_$uid';

  Future<void> _addLocalFlight(String uid, Flight flight) async {
    final flights = [...await _getLocalFlights(uid)];
    final localFlight = Flight(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      originCode: flight.originCode,
      destinationCode: flight.destinationCode,
      date: flight.date,
      travelClass: flight.travelClass,
      emissionsKg: flight.emissionsKg,
      createdAt: flight.createdAt,
      AirlineCode: flight.AirlineCode,
      AirlineNumber: flight.AirlineNumber,
    );
    flights.insert(0, localFlight);
    await _setLocalFlights(uid, flights);
  }

  Future<List<Flight>> _getLocalFlights(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_localFlightsKey(uid));
    if (encoded == null || encoded.isEmpty) return <Flight>[];
    try {
      final rows = jsonDecode(encoded) as List<dynamic>;
      final flights = rows
          .whereType<Map<String, dynamic>>()
          .map((data) => Flight.fromMap(id: data['id'] ?? '', data: data))
          .toList();
      flights.sort((a, b) => b.date.compareTo(a.date));
      return flights;
    } catch (e, st) {
      debugPrint('Could not read local flights: $e');
      debugPrintStack(stackTrace: st);
      return <Flight>[];
    }
  }

  Future<void> _setLocalFlights(String uid, List<Flight> flights) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(flights.map(_flightToLocalJson).toList());
    await prefs.setString(_localFlightsKey(uid), encoded);
  }

  Future<void> _deleteLocalFlight(String uid, String flightId) async {
    final flights = [...await _getLocalFlights(uid)];
    flights.removeWhere((flight) => flight.id == flightId);
    await _setLocalFlights(uid, flights);
  }

  List<Flight> _mergeFlights(List<Flight> remote, List<Flight> local) {
    final flights = [...remote, ...local]
      ..sort((a, b) => b.date.compareTo(a.date));
    return flights;
  }

  Map<String, dynamic> _flightToLocalJson(Flight flight) {
    return {
      'id': flight.id,
      'originCode': flight.originCode,
      'destinationCode': flight.destinationCode,
      'date': flight.date.toIso8601String(),
      'travelClass': flight.travelClass,
      'emissionsKg': flight.emissionsKg,
      'createdAt': flight.createdAt.toIso8601String(),
      'airlineCode': flight.AirlineCode,
      'airlineNumber': flight.AirlineNumber,
    };
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
