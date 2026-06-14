import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/auth_service.dart';

void main() {
  group('AccountDeletionCoordinator', () {
    // ── task 2.4: email/password re-auth before deleteAuthAccount ──────────
    test('email path: reauthWithEmailPassword called before deleteAuthAccount',
        () async {
      final store = FakeAccountDeletionStore(providerId: 'password');
      final coordinator = AccountDeletionCoordinator(store);

      await coordinator.deleteAccount(uid: 'uid-1', password: 'secret');

      final reauthIndex =
          store.calls.indexOf('reauthWithEmailPassword:secret');
      final deleteAuthIndex = store.calls.indexOf('deleteAuthAccount');
      expect(reauthIndex, greaterThanOrEqualTo(0));
      expect(deleteAuthIndex, greaterThan(reauthIndex));
    });

    test('email path: correct password passed to reauthWithEmailPassword',
        () async {
      final store = FakeAccountDeletionStore(providerId: 'password');
      await AccountDeletionCoordinator(store)
          .deleteAccount(uid: 'uid-1', password: 'myPassword123');

      expect(store.calls, contains('reauthWithEmailPassword:myPassword123'));
    });

    // ── task 2.5: Google re-auth before deleteAuthAccount ─────────────────
    test('google path: reauthWithGoogle called before deleteAuthAccount',
        () async {
      final store = FakeAccountDeletionStore(providerId: 'google.com');
      await AccountDeletionCoordinator(store).deleteAccount(uid: 'uid-2');

      final reauthIndex = store.calls.indexOf('reauthWithGoogle');
      final deleteAuthIndex = store.calls.indexOf('deleteAuthAccount');
      expect(reauthIndex, greaterThanOrEqualTo(0));
      expect(deleteAuthIndex, greaterThan(reauthIndex));
    });

    // ── task 2.6: wrong password → error, deleteAuthAccount NOT called ─────
    test('wrong password returns error and does not call deleteAuthAccount',
        () async {
      final store = FakeAccountDeletionStore(
        providerId: 'password',
        reauthEmailError: FirebaseAuthException(code: 'wrong-password'),
      );
      final result = await AccountDeletionCoordinator(store)
          .deleteAccount(uid: 'uid-3', password: 'wrong');

      expect(result.success, isFalse);
      expect(result.error, 'Incorrect password');
      expect(store.calls, isNot(contains('deleteAuthAccount')));
    });

    test('missing password returns error without touching any data', () async {
      final store = FakeAccountDeletionStore(providerId: 'password');
      final result = await AccountDeletionCoordinator(store)
          .deleteAccount(uid: 'uid-4', password: null);

      expect(result.success, isFalse);
      expect(result.error, 'Password is required');
      expect(store.calls, isEmpty);
    });

    // ── task 2.7: Storage object-not-found does not abort the flow ─────────
    test('storage object-not-found is swallowed and deleteAuthAccount still called',
        () async {
      final store = FakeAccountDeletionStore(
        providerId: 'password',
        storageError: FirebaseException(
          plugin: 'firebase_storage',
          code: 'object-not-found',
        ),
      );
      final result = await AccountDeletionCoordinator(store)
          .deleteAccount(uid: 'uid-5', password: 'secret');

      expect(result.success, isTrue);
      expect(store.calls, contains('deleteAuthAccount'));
    });

    test('storage non-404 error propagates as generic error', () async {
      final store = FakeAccountDeletionStore(
        providerId: 'password',
        storageError: FirebaseException(
          plugin: 'firebase_storage',
          code: 'quota-exceeded',
        ),
      );
      final result = await AccountDeletionCoordinator(store)
          .deleteAccount(uid: 'uid-6', password: 'secret');

      expect(result.success, isFalse);
      expect(store.calls, isNot(contains('deleteAuthAccount')));
    });

    // ── ordering: deleteUserData before deleteAuthAccount ─────────────────
    test('deleteUserData is called before deleteAuthAccount', () async {
      final store = FakeAccountDeletionStore(providerId: 'password');
      await AccountDeletionCoordinator(store)
          .deleteAccount(uid: 'uid-7', password: 'pw');

      final dataIndex = store.calls.indexOf('deleteUserData:uid-7');
      final authIndex = store.calls.indexOf('deleteAuthAccount');
      expect(dataIndex, greaterThanOrEqualTo(0));
      expect(authIndex, greaterThan(dataIndex));
    });
  });
}

class FakeAccountDeletionStore implements AccountDeletionStore {
  FakeAccountDeletionStore({
    required this.providerId,
    this.reauthEmailError,
    this.storageError,
  });

  @override
  final String providerId;

  final FirebaseAuthException? reauthEmailError;
  final FirebaseException? storageError;
  final List<String> calls = [];

  @override
  Future<void> reauthWithEmailPassword(String password) async {
    calls.add('reauthWithEmailPassword:$password');
    if (reauthEmailError != null) throw reauthEmailError!;
  }

  @override
  Future<void> reauthWithGoogle() async {
    calls.add('reauthWithGoogle');
  }

  @override
  Future<void> reauthWithApple() async {
    calls.add('reauthWithApple');
  }

  @override
  Future<void> deleteUserData(String uid) async {
    calls.add('deleteUserData:$uid');
  }

  @override
  Future<void> deleteStoragePhoto(String uid) async {
    calls.add('deleteStoragePhoto:$uid');
    if (storageError != null) throw storageError!;
  }

  @override
  Future<void> deleteAuthAccount() async {
    calls.add('deleteAuthAccount');
  }
}
