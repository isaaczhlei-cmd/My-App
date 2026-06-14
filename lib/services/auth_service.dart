import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'firestore_service.dart';

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}

abstract class AuthServiceLike {
  Stream<User?> get authStateChanges;
  Stream<User?> get userChanges;
  User? get currentUser;

  Future<({UserCredential? user, String? error})> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<({UserCredential? user, String? error})> signInWithEmail({
    required String email,
    required String password,
  });

  Future<({bool success, String? error})> sendPasswordResetEmail(String email);

  Future<({bool success, String? error})> sendEmailVerification();

  Future<({bool success, String? error})> reloadCurrentUser();

  Future<({UserCredential? user, String? error})> signInWithGoogle();

  Future<({UserCredential? user, String? error})> signInWithApple();

  Future<({UserCredential? user, String? error})> signInAsGuest();

  bool get isGuest;

  Future<({bool success, String? error})> updateProfilePhoto(File imageFile);

  Future<void> signOut();

  Future<({bool success, String? error})> deleteAccount({String? password});
}

class AuthService implements AuthServiceLike {
  factory AuthService() => _instance;

  AuthService._({
    UserProfileDocumentCoordinator? profileDocumentCoordinator,
    AccountDeletionStore? accountDeletionStore,
  }) : _profileDocumentCoordinator =
           profileDocumentCoordinator ??
           UserProfileDocumentCoordinator(FirestoreUserProfileDocumentStore()),
       _accountDeletionStore = accountDeletionStore;

  @visibleForTesting
  factory AuthService.forTesting({
    required UserProfileDocumentCoordinator profileDocumentCoordinator,
    AccountDeletionStore? accountDeletionStore,
  }) {
    return AuthService._(
      profileDocumentCoordinator: profileDocumentCoordinator,
      accountDeletionStore: accountDeletionStore,
    );
  }

  static final AuthService _instance = AuthService._();

  final UserProfileDocumentCoordinator _profileDocumentCoordinator;
  final AccountDeletionStore? _accountDeletionStore;
  Future<void>? _googleSignInInitialization;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Current user
  @override
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Fires when profile fields (e.g. photo URL) change
  @override
  Stream<User?> get userChanges => _auth.userChanges();

  /// Register with email and password
  @override
  Future<({UserCredential? user, String? error})> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      final user = credential.user;
      if (user != null) {
        final profileError = await _createEmailProfile(
          user,
          displayName: displayName,
        );
        if (profileError != null) {
          try {
            await user.delete();
          } catch (_) {
            // Keep the original profile setup error as the user-facing result.
          }
          return (user: null, error: profileError);
        }

        await sendEmailVerification();
      }

      return (user: credential, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: getErrorMessage(e.code));
    } catch (e) {
      return (user: null, error: 'An unexpected error occurred');
    }
  }

  /// Sign in with email and password
  @override
  Future<({UserCredential? user, String? error})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return (user: credential, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: getErrorMessage(e.code));
    } catch (e) {
      return (user: null, error: 'An unexpected error occurred');
    }
  }

  /// Send password reset email
  @override
  Future<({bool success, String? error})> sendPasswordResetEmail(
    String email,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: 'An unexpected error occurred');
    }
  }

  /// Send a verification email to the current signed-in email user.
  @override
  Future<({bool success, String? error})> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.email == null) {
      return (
        success: false,
        error: 'Sign in with an email account to verify your email',
      );
    }
    if (user.emailVerified) {
      return (success: true, error: null);
    }

    try {
      await user.sendEmailVerification();
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: getErrorMessage(e.code));
    } catch (_) {
      return (success: false, error: 'Could not send verification email');
    }
  }

  /// Reload the current Firebase user from the server.
  @override
  Future<({bool success, String? error})> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return (success: false, error: 'No signed-in user found');
    }

    try {
      await user.reload();
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: getErrorMessage(e.code));
    } catch (_) {
      return (success: false, error: 'Could not refresh your account status');
    }
  }

  /// Sign in with Google
  @override
  Future<({UserCredential? user, String? error})> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow using the new API (google_sign_in 7.x)
      final googleSignIn = GoogleSignIn.instance;
      await _initializeGoogleSignIn(googleSignIn);
      final account = await googleSignIn.authenticate();

      // Get authentication tokens (idToken)
      final authentication = account.authentication;

      // Get authorization for access token
      final authorization = await account.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      // Create credential using the tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: authentication.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return (user: userCredential, error: null);
      }

      final profileError = await _upsertGoogleProfile(user);
      return (user: userCredential, error: profileError);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return (user: null, error: 'Google sign-in was cancelled');
      }
      return (
        user: null,
        error: 'Error signing in with Google: ${e.description}',
      );
    } catch (e) {
      return (user: null, error: 'Error signing in with Google: $e');
    }
  }

  Future<void> _initializeGoogleSignIn(GoogleSignIn googleSignIn) {
    final initialization = _googleSignInInitialization;
    if (initialization != null) {
      return initialization;
    }

    return _googleSignInInitialization = googleSignIn.initialize(
      serverClientId: DefaultFirebaseOptions.ios.iosClientId,
    );
  }

  /// Sign in with Apple (iOS only)
  @override
  Future<({UserCredential? user, String? error})> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user != null) {
        final givenName = appleCredential.givenName;
        final familyName = appleCredential.familyName;
        final displayName = [givenName, familyName]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');

        final profileError = await _upsertAppleProfile(
          user,
          displayName: displayName.isEmpty ? null : displayName,
          email: appleCredential.email,
        );
        if (profileError != null) {
          return (user: userCredential, error: profileError);
        }
      }

      return (user: userCredential, error: null);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return (user: null, error: 'Apple sign-in was cancelled');
      }
      return (user: null, error: 'Error signing in with Apple: ${e.message}');
    } catch (e) {
      return (user: null, error: 'Error signing in with Apple: $e');
    }
  }

  /// Sign in anonymously (guest mode)
  @override
  Future<({UserCredential? user, String? error})> signInAsGuest() async {
    try {
      final credential = await _auth.signInAnonymously();
      return (user: credential, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: getErrorMessage(e.code));
    } catch (e) {
      return (user: null, error: 'An unexpected error occurred');
    }
  }

  /// Check if current user is anonymous (guest)
  @override
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  Future<String?> _createEmailProfile(
    User user, {
    required String? displayName,
  }) async {
    return _profileDocumentCoordinator.createEmailProfile(
      uid: user.uid,
      displayName: _firstNonEmpty(displayName, user.displayName),
      email: user.email,
    );
  }

  Future<String?> _upsertGoogleProfile(User user) async {
    return _profileDocumentCoordinator.upsertGoogleProfile(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
    );
  }

  Future<String?> _upsertAppleProfile(
    User user, {
    required String? displayName,
    required String? email,
  }) async {
    return _profileDocumentCoordinator.upsertAppleProfile(
      uid: user.uid,
      displayName: displayName,
      email: email,
    );
  }

  String? _firstNonEmpty(String? first, String? second) {
    final trimmedFirst = first?.trim();
    if (trimmedFirst != null && trimmedFirst.isNotEmpty) {
      return trimmedFirst;
    }

    final trimmedSecond = second?.trim();
    if (trimmedSecond != null && trimmedSecond.isNotEmpty) {
      return trimmedSecond;
    }

    return null;
  }

  /// Upload a new profile photo (signed-in, non-anonymous users only).
  @override
  Future<({bool success, String? error})> updateProfilePhoto(
    File imageFile,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return (
        success: false,
        error: 'Sign in with an account to add a profile photo',
      );
    }
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Could not update photo: $e');
    }
  }

  /// Permanently delete the account: re-authenticate, wipe all user data, then
  /// delete the Firebase Auth record. [password] is required for email users;
  /// omit for Google users (re-auth via Google Sign-In is triggered instead).
  @override
  Future<({bool success, String? error})> deleteAccount({
    String? password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return (success: false, error: 'No signed-in user found');
    }
    final store = _accountDeletionStore ??
        FirebaseAccountDeletionStore(user, _initializeGoogleSignIn);
    return AccountDeletionCoordinator(store).deleteAccount(
      uid: user.uid,
      password: password,
    );
  }

  /// Sign out
  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Ignore if not signed in with Google
    }
    await _auth.signOut();
  }

  /// Convert Firebase error codes to user-friendly messages
  @visibleForTesting
  static String getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'requires-recent-login':
        return 'Please sign in again before deleting your account';
      default:
        return 'An error occurred. Please try again';
    }
  }
}

// ─── Account deletion ────────────────────────────────────────────────────────

@visibleForTesting
abstract class AccountDeletionStore {
  String get providerId;
  Future<void> reauthWithEmailPassword(String password);
  Future<void> reauthWithGoogle();
  Future<void> reauthWithApple();
  Future<void> deleteUserData(String uid);
  Future<void> deleteStoragePhoto(String uid);
  Future<void> deleteAuthAccount();
}

@visibleForTesting
class AccountDeletionCoordinator {
  const AccountDeletionCoordinator(this._store);

  final AccountDeletionStore _store;

  Future<({bool success, String? error})> deleteAccount({
    required String uid,
    String? password,
  }) async {
    try {
      final providerId = _store.providerId;
      if (providerId == 'password') {
        if (password == null || password.isEmpty) {
          return (success: false, error: 'Password is required');
        }
        await _store.reauthWithEmailPassword(password);
      } else if (providerId == 'google.com') {
        await _store.reauthWithGoogle();
      } else if (providerId == 'apple.com') {
        await _store.reauthWithApple();
      }

      await _store.deleteUserData(uid);

      try {
        await _store.deleteStoragePhoto(uid);
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }

      await _store.deleteAuthAccount();
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: AuthService.getErrorMessage(e.code));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return (success: false, error: 'Sign-in cancelled');
      }
      return (
        success: false,
        error: 'Could not re-authenticate: ${e.description}',
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return (success: false, error: 'Sign-in cancelled');
      }
      return (
        success: false,
        error: 'Could not re-authenticate: ${e.message}',
      );
    } catch (e) {
      return (success: false, error: 'An unexpected error occurred');
    }
  }
}

class FirebaseAccountDeletionStore implements AccountDeletionStore {
  FirebaseAccountDeletionStore(this._user, this._initGoogleSignIn);

  final User _user;
  final Future<void> Function(GoogleSignIn) _initGoogleSignIn;

  @override
  String get providerId =>
      _user.providerData.isEmpty ? '' : _user.providerData.first.providerId;

  @override
  Future<void> reauthWithEmailPassword(String password) async {
    final cred = EmailAuthProvider.credential(
      email: _user.email!,
      password: password,
    );
    await _user.reauthenticateWithCredential(cred);
  }

  @override
  Future<void> reauthWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await _initGoogleSignIn(googleSignIn);
    final account = await googleSignIn.authenticate();
    final auth = account.authentication;
    final authorization = await account.authorizationClient.authorizeScopes([
      'email',
      'profile',
    ]);
    final cred = GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: auth.idToken,
    );
    await _user.reauthenticateWithCredential(cred);
  }

  @override
  Future<void> reauthWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final cred = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    await _user.reauthenticateWithCredential(cred);
  }

  @override
  Future<void> deleteUserData(String uid) =>
      FirestoreService().deleteUserData(uid);

  @override
  Future<void> deleteStoragePhoto(String uid) => FirebaseStorage.instance
      .ref()
      .child('profile_photos')
      .child('$uid.jpg')
      .delete();

  @override
  Future<void> deleteAuthAccount() => _user.delete();
}

// ─── User profile document ────────────────────────────────────────────────────

@visibleForTesting
class UserProfileDocument {
  const UserProfileDocument({
    required this.uid,
    required this.displayName,
    required this.email,
  });

  final String uid;
  final String? displayName;
  final String? email;

  Map<String, Object?> toFirestore({
    required Object createdAt,
    required bool includeCreatedAt,
  }) {
    return <String, Object?>{
      'displayName': displayName,
      'email': email,
      if (includeCreatedAt) 'createdAt': createdAt,
      'isAnonymous': false,
    };
  }
}

@visibleForTesting
abstract class UserProfileDocumentStore {
  Future<bool> exists(String uid);

  Future<void> setProfile(
    UserProfileDocument profile, {
    required bool includeCreatedAt,
  });

  Future<void> mergeFields(String uid, Map<String, Object?> fields);
}

@visibleForTesting
class UserProfileDocumentCoordinator {
  const UserProfileDocumentCoordinator(this._store);

  final UserProfileDocumentStore _store;

  Future<String?> createEmailProfile({
    required String uid,
    required String? displayName,
    required String? email,
  }) async {
    final profile = UserProfileDocument(
      uid: uid,
      displayName: displayName,
      email: email,
    );

    try {
      await _store.setProfile(profile, includeCreatedAt: true);
      return null;
    } catch (_) {
      return 'Could not set up your account profile. Check your connection and try again.';
    }
  }

  Future<String?> upsertGoogleProfile({
    required String uid,
    required String? displayName,
    required String? email,
  }) async {
    final profile = UserProfileDocument(
      uid: uid,
      displayName: displayName,
      email: email,
    );

    try {
      final exists = await _store.exists(uid);
      await _store.setProfile(profile, includeCreatedAt: !exists);
      return null;
    } catch (_) {
      return 'Signed in, but could not update your account profile. Check your connection and try again.';
    }
  }

  Future<String?> upsertAppleProfile({
    required String uid,
    required String? displayName,
    required String? email,
  }) async {
    // Apple only sends name/email on first authorization — skip null fields
    // so subsequent sign-ins don't overwrite existing profile data.
    final fields = <String, Object?>{
      'isAnonymous': false,
      'displayName': ?displayName,
      'email': ?email,
    };

    try {
      final exists = await _store.exists(uid);
      if (!exists) {
        fields['createdAt'] = FieldValue.serverTimestamp();
      }
      await _store.mergeFields(uid, fields);
      return null;
    } catch (_) {
      return 'Signed in, but could not update your account profile. Check your connection and try again.';
    }
  }
}

class FirestoreUserProfileDocumentStore implements UserProfileDocumentStore {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Future<bool> exists(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.exists;
  }

  @override
  Future<void> setProfile(
    UserProfileDocument profile, {
    required bool includeCreatedAt,
  }) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(
          profile.toFirestore(
            createdAt: FieldValue.serverTimestamp(),
            includeCreatedAt: includeCreatedAt,
          ),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> mergeFields(String uid, Map<String, Object?> fields) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(fields, SetOptions(merge: true));
  }
}
