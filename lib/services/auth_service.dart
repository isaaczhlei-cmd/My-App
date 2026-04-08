import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  Future<({UserCredential? user, String? error})> signInWithGoogle();

  Future<({UserCredential? user, String? error})> signInAsGuest();

  bool get isGuest;

  Future<({bool success, String? error})> updateProfilePhoto(File imageFile);

  Future<void> signOut();
}

class AuthService implements AuthServiceLike {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Fires when profile fields (e.g. photo URL) change
  Stream<User?> get userChanges => _auth.userChanges();

  /// Register with email and password
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

      return (user: credential, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _getErrorMessage(e.code));
    } catch (e) {
      return (user: null, error: 'An unexpected error occurred');
    }
  }

  /// Sign in with email and password
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
      return (user: null, error: _getErrorMessage(e.code));
    } catch (e) {
      return (user: null, error: 'An unexpected error occurred');
    }
  }

  /// Send password reset email
  Future<({bool success, String? error})> sendPasswordResetEmail(
    String email,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: 'An unexpected error occurred');
    }
  }

  /// Sign in with Google
  Future<({UserCredential? user, String? error})> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow using the new API (google_sign_in 7.x)
      final googleSignIn = GoogleSignIn.instance;
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
      return (user: userCredential, error: null);
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

  /// Sign in anonymously (guest mode)
  Future<({UserCredential? user, String? error})> signInAsGuest() async {
    try {
      final credential = await _auth.signInAnonymously();
      return (user: credential, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _getErrorMessage(e.code));
    } catch (e) {
      return (user: null, error: 'An unexpected error occurred');
    }
  }

  /// Check if current user is anonymous (guest)
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  /// Upload a new profile photo (signed-in, non-anonymous users only).
  Future<({bool success, String? error})> updateProfilePhoto(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return (success: false, error: 'Sign in with an account to add a profile photo');
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
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Ignore if not signed in with Google
    }
    await _auth.signOut();
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
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
