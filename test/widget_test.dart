import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/auth/login_screen.dart';
import 'package:my_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpOverrides? previousHttpOverrides;

  setUpAll(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  group('AuthService', () {
    test('reuses the same production instance', () {
      expect(identical(AuthService(), AuthService()), isTrue);
    });
  });

  group('Forgot password', () {
    testWidgets('renders Forgot Password button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: FakeAuthService())),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('opens reset screen when forgot password is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: FakeAuthService())),
      );

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (WidgetTester tester) async {
      final fakeAuthService = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter your email'),
        findsOneWidget,
      );
      expect(fakeAuthService.resetEmails, isEmpty);
    });

    testWidgets('shows snackbar when reset succeeds', (
      WidgetTester tester,
    ) async {
      final fakeAuthService = FakeAuthService(
        passwordResetResult: (success: true, error: null),
      );

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('user@example.com'), findsOneWidget);
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(fakeAuthService.resetEmails, ['user@example.com']);
      expect(find.text('Check Your Email'), findsOneWidget);
    });

    testWidgets('shows banner when reset fails', (WidgetTester tester) async {
      final fakeAuthService = FakeAuthService(
        passwordResetResult: (success: false, error: 'Some error'),
      );

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(fakeAuthService.resetEmails, ['user@example.com']);
      expect(find.text('Some error'), findsOneWidget);
    });
  });

  group('LoginScreen auth injection', () {
    testWidgets('uses injected auth service for email login', (
      WidgetTester tester,
    ) async {
      final fakeAuthService = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(fakeAuthService.emailSignIns, [
        (email: 'user@example.com', password: 'password123'),
      ]);
    });

    testWidgets('uses injected auth service for signup', (
      WidgetTester tester,
    ) async {
      final fakeAuthService = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'Password123',
      );
      await tester.pump();
      final createAccountButton = find.widgetWithText(
        ElevatedButton,
        'Create Account',
      );
      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(fakeAuthService.registrations, [
        (
          displayName: 'Test User',
          email: 'new@example.com',
          password: 'Password123',
        ),
      ]);
    });

    testWidgets('uses injected auth service for Google sign-in', (
      WidgetTester tester,
    ) async {
      final fakeAuthService = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      final googleButton = find.text('Continue with Google');
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(fakeAuthService.googleSignInCount, 1);
    });

    testWidgets('uses injected auth service for password reset', (
      WidgetTester tester,
    ) async {
      final fakeAuthService = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuthService)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'reset@example.com',
      );
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(fakeAuthService.resetEmails, ['reset@example.com']);
    });
  });
}

class FakeAuthService implements AuthServiceLike {
  FakeAuthService({
    this.passwordResetResult = const (success: true, error: null),
  });

  final ({bool success, String? error}) passwordResetResult;
  final List<String> resetEmails = <String>[];
  final List<({String email, String password})> emailSignIns =
      <({String email, String password})>[];
  final List<({String displayName, String email, String password})>
      registrations =
      <({String displayName, String email, String password})>[];
  int googleSignInCount = 0;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  User? get currentUser => null;

  @override
  bool get isGuest => false;

  @override
  Future<({UserCredential? user, String? error})> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    registrations.add((
      displayName: displayName ?? '',
      email: email,
      password: password,
    ));
    return (user: null, error: null);
  }

  @override
  Future<({UserCredential? user, String? error})> signInAsGuest() async {
    throw UnimplementedError();
  }

  @override
  Future<({UserCredential? user, String? error})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailSignIns.add((email: email, password: password));
    return (user: null, error: null);
  }

  @override
  Future<({UserCredential? user, String? error})> signInWithGoogle() async {
    googleSignInCount++;
    return (user: null, error: null);
  }

  @override
  Future<void> signOut() async {
    throw UnimplementedError();
  }

  @override
  Future<({bool success, String? error})> sendPasswordResetEmail(
    String email,
  ) async {
    resetEmails.add(email);
    return passwordResetResult;
  }

  @override
  Future<({bool success, String? error})> updateProfilePhoto(
    File imageFile,
  ) async {
    throw UnimplementedError();
  }

  @override
  Stream<User?> get userChanges => const Stream<User?>.empty();
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _TestHttpClientRequest();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async {
    return _TestHttpClientResponse();
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpHeaders get headers => _TestHttpHeaders();

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) {
    if (name.toLowerCase() == HttpHeaders.contentTypeHeader) {
      return <String>['image/png'];
    }
    return null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _transparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9sY9lO8AAAAASUVORK5CYII=',
);
