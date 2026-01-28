import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return (user: null, error: 'Google sign-in was cancelled');
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      return (user: userCredential, error: null);
    } catch (e) {
      return (user: null, error: 'Error signing in with Google');
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

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
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
