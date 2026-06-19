import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/user_preferences_service.dart';
import 'widgets/airplane_mode_overlay.dart';
import 'widgets/error_screen.dart';

/// Thrown by [_bootstrap] to annotate a stage failure.
class _BootstrapException implements Exception {
  _BootstrapException(this.stage, this.error, this.stack);
  final BootstrapStage stage;
  final Object error;
  final StackTrace stack;

  @override
  String toString() => '_BootstrapException(${stage.name}): $error';
}

void _logBootstrapError(Object error, StackTrace stack, {String? stage}) {
  debugPrint('[bootstrap:${stage ?? '?'}] $error');
  debugPrint(stack.toString());
}

Future<void> _bootstrap() async {
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e, st) {
    _logBootstrapError(e, st, stage: BootstrapStage.dotenv.name);
    throw _BootstrapException(BootstrapStage.dotenv, e, st);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    _logBootstrapError(e, st, stage: BootstrapStage.firebase.name);
    throw _BootstrapException(BootstrapStage.firebase, e, st);
  }
}

Future<void> _retryBootstrap() async {
  try {
    await _bootstrap();
    await UserPreferencesService.instance.load();
    runApp(const MyApp());
  } on _BootstrapException catch (be) {
    runApp(
      ErrorApp(
        stage: be.stage,
        error: be.error,
        stack: be.stack,
        onRetry: _retryBootstrap,
      ),
    );
  } catch (e, st) {
    _logBootstrapError(e, st, stage: BootstrapStage.unknown.name);
    runApp(
      ErrorApp(
        stage: BootstrapStage.unknown,
        error: e,
        stack: st,
        onRetry: _retryBootstrap,
      ),
    );
  }
}

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        _logBootstrapError(
          details.exception,
          details.stack ?? StackTrace.empty,
          stage: 'widget',
        );
        FlutterError.presentError(details);
      };

      try {
        await _bootstrap();
        await UserPreferencesService.instance.load();
        runApp(const MyApp());
      } on _BootstrapException catch (be) {
        runApp(
          ErrorApp(
            stage: be.stage,
            error: be.error,
            stack: be.stack,
            onRetry: _retryBootstrap,
          ),
        );
      } catch (e, st) {
        _logBootstrapError(e, st, stage: BootstrapStage.unknown.name);
        runApp(
          ErrorApp(
            stage: BootstrapStage.unknown,
            error: e,
            stack: st,
            onRetry: _retryBootstrap,
          ),
        );
      }
    },
    (error, stack) {
      _logBootstrapError(error, stack, stage: 'zone');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPreferencesService.instance,
      builder: (context, _) {
        final prefs = UserPreferencesService.instance;
        return MaterialApp(
          title: 'FlightPrint',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildTheme(prefs.accentColor, Brightness.light),
          darkTheme: AppTheme.buildTheme(prefs.accentColor, Brightness.dark),
          themeMode: prefs.themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

/// Listens to auth state and shows Login or Home screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // Only fully signed-in accounts should reach the app home.
        if (user != null && !user.isAnonymous) {
          return const AirplaneModeOverlay(child: HomeScreen());
        }

        // Signed out or anonymous users go to the auth flow.
        return const LoginScreen();
      },
    );
  }
}
