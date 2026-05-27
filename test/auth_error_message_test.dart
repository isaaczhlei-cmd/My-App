import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/auth_service.dart';

void main() {
  group('AuthService.getErrorMessage', () {
    test('maps Firebase auth codes to user-facing messages', () {
      expect(
        AuthService.getErrorMessage('weak-password'),
        'Password should be at least 6 characters',
      );
      expect(
        AuthService.getErrorMessage('email-already-in-use'),
        'An account already exists with this email',
      );
      expect(
        AuthService.getErrorMessage('invalid-email'),
        'Please enter a valid email address',
      );
      expect(
        AuthService.getErrorMessage('user-not-found'),
        'No account found with this email',
      );
      expect(
        AuthService.getErrorMessage('wrong-password'),
        'Incorrect password',
      );
      expect(
        AuthService.getErrorMessage('user-disabled'),
        'This account has been disabled',
      );
      expect(
        AuthService.getErrorMessage('too-many-requests'),
        'Too many attempts. Please try again later',
      );
      expect(
        AuthService.getErrorMessage('invalid-credential'),
        'Invalid email or password',
      );
    });

    test('returns fallback message for unknown codes', () {
      expect(
        AuthService.getErrorMessage('unknown-code'),
        'An error occurred. Please try again',
      );
    });
  });
}
