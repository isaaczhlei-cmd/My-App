import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/screens/auth/widgets/signup_form.dart';

void main() {
  group('SignupFormValidator', () {
    test('rejects invalid signup input', () {
      expect(
        SignupFormValidator.isFormValid(
          name: 'A',
          email: 'user@example.com',
          password: 'Password123',
          confirmPassword: 'Password123',
        ),
        isFalse,
      );
      expect(
        SignupFormValidator.isFormValid(
          name: 'Test User',
          email: 'not-email',
          password: 'Password123',
          confirmPassword: 'Password123',
        ),
        isFalse,
      );
      expect(
        SignupFormValidator.isFormValid(
          name: 'Test User',
          email: 'user@example.com',
          password: 'short',
          confirmPassword: 'short',
        ),
        isFalse,
      );
      expect(
        SignupFormValidator.isFormValid(
          name: 'Test User',
          email: 'user@example.com',
          password: 'Password123',
          confirmPassword: 'Different123',
        ),
        isFalse,
      );
    });

    test('accepts valid signup input', () {
      expect(
        SignupFormValidator.isFormValid(
          name: 'Test User',
          email: 'user@example.com',
          password: 'Password123',
          confirmPassword: 'Password123',
        ),
        isTrue,
      );
    });
  });
}
