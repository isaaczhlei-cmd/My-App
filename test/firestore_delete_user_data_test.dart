import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/firestore_service.dart';

void main() {
  group('UserDataDeletionCoordinator', () {
    test('deletes flights then user doc in a single batch', () async {
      final store = FakeUserDataStore(batchResults: [3]);
      final coordinator = UserDataDeletionCoordinator(store);
      await coordinator.deleteUserData('uid-1');

      expect(store.calls, [
        'deleteFlightsBatch:uid-1',
        'deleteUserDoc:uid-1',
      ]);
    });

    test('loops when first batch is full (400), then deletes doc', () async {
      final store = FakeUserDataStore(batchResults: [400, 2]);
      final coordinator = UserDataDeletionCoordinator(store);
      await coordinator.deleteUserData('uid-2');

      expect(store.calls, [
        'deleteFlightsBatch:uid-2',
        'deleteFlightsBatch:uid-2',
        'deleteUserDoc:uid-2',
      ]);
    });

    test('deletes user doc even when there are no flights', () async {
      final store = FakeUserDataStore(batchResults: [0]);
      final coordinator = UserDataDeletionCoordinator(store);
      await coordinator.deleteUserData('uid-3');

      expect(store.calls, [
        'deleteFlightsBatch:uid-3',
        'deleteUserDoc:uid-3',
      ]);
    });

    test('user doc deleted only after all flight batches', () async {
      final store = FakeUserDataStore(batchResults: [400, 3]);
      final coordinator = UserDataDeletionCoordinator(store);
      await coordinator.deleteUserData('uid-4');

      final deleteDocIndex = store.calls.indexOf('deleteUserDoc:uid-4');
      final lastBatchIndex = store.calls
          .lastIndexWhere((c) => c == 'deleteFlightsBatch:uid-4');
      expect(lastBatchIndex, lessThan(deleteDocIndex));
    });
  });
}

class FakeUserDataStore implements UserDataStore {
  FakeUserDataStore({required this.batchResults});

  final List<int> batchResults;
  int _callIndex = 0;
  final List<String> calls = [];

  @override
  Future<int> deleteFlightsBatch(String uid, {required int limit}) async {
    calls.add('deleteFlightsBatch:$uid');
    return _callIndex < batchResults.length ? batchResults[_callIndex++] : 0;
  }

  @override
  Future<void> deleteUserDoc(String uid) async {
    calls.add('deleteUserDoc:$uid');
  }
}
