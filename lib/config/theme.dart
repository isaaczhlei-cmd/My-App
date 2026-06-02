import 'package:flutter/material.dart';

/// Centralized color constants for the Flight Carbon Tracker app.
/// Non-accent colors (backgrounds, text, status) remain static constants.
/// Accent color is runtime-dynamic via UserPreferencesService + buildTheme().
class AppColors {
  // Primary brand color — kept as const fallback for const-constructor contexts.
  // Interactive widgets should use Theme.of(context).colorScheme.primary instead.
  // TODO: migrate remaining AppColors.primaryGreen usages to colorScheme.primary:
  //   add_flight_screen.dart:338  (date picker colorScheme override - const context)
  //   add_flight_screen.dart:693  (const Icon in const section)
  //   add_flight_screen.dart:895  (featured text - const context)
  //   auth/forgot_password_screen.dart:92,168,197,203,273  (auth screen, lower priority)
  //   auth/login_screen.dart:202,245,249,415,427,432,583   (auth screen, lower priority)
  //   auth/widgets/signup_form.dart:57                     (const local, auth screen)
  //   book_flight_screen.dart:118,119                      (colorScheme override - const)
  //   booking_handoff_screen.dart:168                      (ternary)
  //   guest_sign_in_prompt_screen.dart:39,41               (const context)
  static const Color primaryGreen = Color(0xFF64B067);

  // Background colors
  static const Color darkBackground = Color(0xFF0D1B2A);
  static const Color cardBackground = Color(0xFF1B2838);
  static const Color surface = Color(0xFF243447);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);

  // Status colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
}

class AppTheme {
  // Legacy color references — use AppColors directly for new code
  static const Color primaryGreen = AppColors.primaryGreen;
  static const Color darkBackground = AppColors.darkBackground;
  static const Color cardBackground = AppColors.cardBackground;
  static const Color surfaceColor = AppColors.surface;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;

  /// Builds a ThemeData for the given accent color and brightness.
  /// Call twice in MyApp: once for Brightness.light (theme:) and once for
  /// Brightness.dark (darkTheme:). Pass themeMode separately to MaterialApp.
  static ThemeData buildTheme(Color accent, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      // Preserve exact non-seed backgrounds to maintain design intent
      surface: brightness == Brightness.dark ? AppColors.cardBackground : null,
    );

    final scaffoldBg = brightness == Brightness.dark
        ? AppColors.darkBackground
        : const Color(0xFFF5F5F5);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark ? AppColors.cardBackground : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark ? AppColors.cardBackground : Colors.white,
        selectedItemColor: accent,
        unselectedItemColor: brightness == Brightness.dark
            ? AppColors.textSecondary
            : const Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        foregroundColor: brightness == Brightness.dark
            ? AppColors.textPrimary
            : const Color(0xFF1A1A2E),
      ),
    );
  }

  // Keep darkTheme getter for any legacy call sites during migration
  static ThemeData get darkTheme => buildTheme(AppColors.primaryGreen, Brightness.dark);
}
