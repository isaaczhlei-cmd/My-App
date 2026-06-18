import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/services/auth_service.dart';

void main() {
  group('UserProfileDocumentCoordinator', () {
    test('creates an email profile with createdAt included', () async {
      final store = FakeUserProfileDocumentStore();
      final coordinator = UserProfileDocumentCoordinator(store);

      final error = await coordinator.createEmailProfile(
        uid: 'user-1',
        displayName: 'Test User',
        email: 'test@example.com',
      );

      expect(error, isNull);
      expect(store.existsChecks, isEmpty);
      expect(store.writes, hasLength(1));
      expect(store.writes.single.profile.uid, 'user-1');
      expect(store.writes.single.includeCreatedAt, isTrue);
      expect(store.writes.single.profile.displayName, 'Test User');
      expect(store.writes.single.profile.email, 'test@example.com');
    });

    test('creates a Google profile when no document exists', () async {
      final store = FakeUserProfileDocumentStore(existsResult: false);
      final coordinator = UserProfileDocumentCoordinator(store);

      final error = await coordinator.upsertGoogleProfile(
        uid: 'google-1',
        displayName: 'Google User',
        email: 'google@example.com',
      );

      expect(error, isNull);
      expect(store.existsChecks, ['google-1']);
      expect(store.writes.single.includeCreatedAt, isTrue);
    });

    test('preserves createdAt for returning Google users', () async {
      final store = FakeUserProfileDocumentStore(existsResult: true);
      final coordinator = UserProfileDocumentCoordinator(store);

      final error = await coordinator.upsertGoogleProfile(
        uid: 'google-2',
        displayName: 'Updated Name',
        email: 'updated@example.com',
      );

      expect(error, isNull);
      expect(store.existsChecks, ['google-2']);
      expect(store.writes.single.includeCreatedAt, isFalse);
      expect(store.writes.single.profile.displayName, 'Updated Name');
      expect(store.writes.single.profile.email, 'updated@example.com');
    });

    test('returns email rollback error when profile creation fails', () async {
      final store = FakeUserProfileDocumentStore(throwOnSet: true);
      final coordinator = UserProfileDocumentCoordinator(store);

      final error = await coordinator.createEmailProfile(
        uid: 'user-2',
        displayName: null,
        email: 'fail@example.com',
      );

      expect(
        error,
        'Could not set up your account profile. Check your connection and try again.',
      );
    });

    test('returns Google warning error when profile upsert fails', () async {
      final store = FakeUserProfileDocumentStore(throwOnSet: true);
      final coordinator = UserProfileDocumentCoordinator(store);

      final error = await coordinator.upsertGoogleProfile(
        uid: 'google-3',
        displayName: 'Google User',
        email: 'google@example.com',
      );

      expect(
        error,
        'Signed in, but could not update your account profile. Check your connection and try again.',
      );
    });
  });

  group('UserProfileDocument', () {
    test('serializes required fields and optional createdAt', () {
      const profile = UserProfileDocument(
        uid: 'user-3',
        displayName: null,
        email: 'user3@example.com',
      );

      expect(
        profile.toFirestore(createdAt: 'server-time', includeCreatedAt: true),
        <String, Object?>{
          'displayName': null,
          'email': 'user3@example.com',
          'createdAt': 'server-time',
          'isAnonymous': false,
        },
      );

      expect(
        profile.toFirestore(createdAt: 'server-time', includeCreatedAt: false),
        <String, Object?>{
          'displayName': null,
          'email': 'user3@example.com',
          'isAnonymous': false,
        },
      );
    });
  });
}

class FakeUserProfileDocumentStore implements UserProfileDocumentStore {
  FakeUserProfileDocumentStore({
    this.existsResult = false,
    this.throwOnSet = false,
  });

  final bool existsResult;
  final bool throwOnSet;
  final List<String> existsChecks = <String>[];
  final List<ProfileWrite> writes = <ProfileWrite>[];

  @override
  Future<bool> exists(String uid) async {
    existsChecks.add(uid);
    return existsResult;
  }

  @override
  Future<void> setProfile(
    UserProfileDocument profile, {
    required bool includeCreatedAt,
  }) async {
    if (throwOnSet) {
      throw StateError('write failed');
    }
    writes.add(
      ProfileWrite(profile: profile, includeCreatedAt: includeCreatedAt),
    );
  }

  @override
  Future<void> mergeFields(String uid, Map<String, Object?> fields) async {
    if (throwOnSet) throw StateError('write failed');
  }
}

class ProfileWrite {
  const ProfileWrite({required this.profile, required this.includeCreatedAt});

  final UserProfileDocument profile;
  final bool includeCreatedAt;
}
