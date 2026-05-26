import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Stage at which bootstrap failed.
enum BootstrapStage { dotenv, firebase, unknown }

/// Top-level fallback app shown when [_bootstrap] fails.
///
/// Mounts a [MaterialApp] themed identically to [MyApp] so the user
/// transition into the error UI is visually seamless.
class ErrorApp extends StatelessWidget {
  const ErrorApp({
    super.key,
    required this.stage,
    required this.error,
    required this.stack,
    this.onRetry,
  });

  final BootstrapStage stage;
  final Object error;
  final StackTrace stack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flight Carbon Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ErrorScreen(
        stage: stage,
        error: error,
        stack: stack,
        onRetry: onRetry,
      ),
    );
  }
}

/// Stage-aware fallback UI for bootstrap failures.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    super.key,
    required this.stage,
    required this.error,
    required this.stack,
    this.onRetry,
  });

  final BootstrapStage stage;
  final Object error;
  final StackTrace stack;
  final VoidCallback? onRetry;

  String get _title {
    switch (stage) {
      case BootstrapStage.dotenv:
        return 'Configuration missing';
      case BootstrapStage.firebase:
        return 'Can\'t reach our services';
      case BootstrapStage.unknown:
        return 'Something went wrong';
    }
  }

  String get _body {
    switch (stage) {
      case BootstrapStage.dotenv:
        return 'The app couldn\'t load its configuration file. '
            'Please reinstall or update the app to restore missing settings.';
      case BootstrapStage.firebase:
        return 'We couldn\'t connect to the service backend. '
            'Check your network connection and try again.';
      case BootstrapStage.unknown:
        return 'An unexpected error occurred while starting the app.';
    }
  }

  bool get _showRetry =>
      stage == BootstrapStage.firebase && onRetry != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningOrange,
                size: 72,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Diagnostics (debug only)',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'stage: ${stage.name}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error.toString(),
                                style: const TextStyle(
                                  color: AppColors.errorRed,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                stack.toString(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showRetry) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
