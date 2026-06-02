import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Future<({UserCredential? user, String? error})> signInAsGuest();

  bool get isGuest;

  Future<({bool success, String? error})> updateProfilePhoto(File imageFile);

  Future<void> signOut();
}

class AuthService implements AuthServiceLike {
  factory AuthService() => _instance;

  AuthService._({UserProfileDocumentCoordinator? profileDocumentCoordinator})
    : _profileDocumentCoordinator =
          profileDocumentCoordinator ??
          UserProfileDocumentCoordinator(FirestoreUserProfileDocumentStore());

  @visibleForTesting
  factory AuthService.forTesting({
    required UserProfileDocumentCoordinator profileDocumentCoordinator,
  }) {
    return AuthService._(
      profileDocumentCoordinator: profileDocumentCoordinator,
    );
  }

  static final AuthService _instance = AuthService._();

  final UserProfileDocumentCoordinator _profileDocumentCoordinator;
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
      final googleSignInConfigError = _ensureGoogleSignInConfigured();
      if (googleSignInConfigError != null) {
        return (user: null, error: googleSignInConfigError);
      }

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

  String? _ensureGoogleSignInConfigured() {
    final serverClientId = dotenv.env['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'];
    if (serverClientId == null ||
        serverClientId.trim().isEmpty ||
        serverClientId == 'local-placeholder') {
      return 'Google sign-in is not configured. Add GOOGLE_SIGN_IN_SERVER_CLIENT_ID from Firebase web client settings.';
    }

    return null;
  }

  Future<void> _initializeGoogleSignIn(GoogleSignIn googleSignIn) {
    final initialization = _googleSignInInitialization;
    if (initialization != null) {
      return initialization;
    }

    return _googleSignInInitialization = googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'],
    );
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
      default:
        return 'An error occurred. Please try again';
    }
  }
}

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
}
