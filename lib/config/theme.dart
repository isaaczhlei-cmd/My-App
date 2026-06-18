import 'package:flutter/material.dart';

/// Centralized color constants for the Flight Carbon Tracker app.
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
  // Primary brand color — slightly more saturated for better visibility in dark
  static const Color primaryGreen = Color(0xFF2ECC71);

  // Background colors — stronger separation for improved legibility
  static const Color darkBackground = Color(0xFF021217);
  static const Color cardBackground = Color(0xFF0A1A22);
  static const Color surface = Color(0xFF0F2A32);

  // Text colors — slightly brighter off-white for clarity on dark
  static const Color textPrimary = Color(0xFFF4FBF9);
  static const Color textSecondary = Color(0xFF90A8AD);

  // Status colors — vivid variants to stand out against dark backgrounds
  static const Color successGreen = Color(0xFF28C67A);
  static const Color warningOrange = Color(0xFFFFA726);
  static const Color errorRed = Color(0xFFF44336);
}

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.card,
    required this.cardMuted,
    required this.elevatedSurface,
    required this.onCard,
    required this.onCardMuted,
    required this.outlineSoft,
    required this.logoPlate,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color card;
  final Color cardMuted;
  final Color elevatedSurface;
  final Color onCard;
  final Color onCardMuted;
  final Color outlineSoft;
  final Color logoPlate;
  final Color successContainer;
  final Color onSuccessContainer;

  @override
  AppThemeColors copyWith({
    Color? card,
    Color? cardMuted,
    Color? elevatedSurface,
    Color? onCard,
    Color? onCardMuted,
    Color? outlineSoft,
    Color? logoPlate,
    Color? successContainer,
    Color? onSuccessContainer,
  }) {
    return AppThemeColors(
      card: card ?? this.card,
      cardMuted: cardMuted ?? this.cardMuted,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      onCard: onCard ?? this.onCard,
      onCardMuted: onCardMuted ?? this.onCardMuted,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      logoPlate: logoPlate ?? this.logoPlate,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      card: Color.lerp(card, other.card, t)!,
      cardMuted: Color.lerp(cardMuted, other.cardMuted, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      onCard: Color.lerp(onCard, other.onCard, t)!,
      onCardMuted: Color.lerp(onCardMuted, other.onCardMuted, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      logoPlate: Color.lerp(logoPlate, other.logoPlate, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}

extension AppThemeLookup on BuildContext {
  AppThemeColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppThemeColors>() ??
        AppTheme.colorsFor(theme.brightness);
  }
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
    final themeColors = colorsFor(brightness);
    final isDark = brightness == Brightness.dark;
    final resolvedAccent = accentForBrightness(accent, brightness);
    final scaffoldBg = isDark
        ? AppColors.darkBackground
        : const Color(0xFFF4F7F3);
    final card = themeColors.card;
    final cardMuted = themeColors.cardMuted;
    final elevatedSurface = themeColors.elevatedSurface;
    final onCard = themeColors.onCard;
    final onCardMuted = themeColors.onCardMuted;
    final outlineSoft = themeColors.outlineSoft;

    // Keep selected dark-mode accents saturated but darker, so large surfaces
    // read as dark green, dark red, etc. instead of pastel highlights.
    final seedColor = isDark
        ? resolvedAccent
        : Color.lerp(accent, Colors.white, 0.48)!;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ).copyWith(
          surface: card,
          onSurface: onCard,
          surfaceContainerHighest: cardMuted,
          onSurfaceVariant: onCardMuted,
          outlineVariant: outlineSoft,
          primary: resolvedAccent,
          onPrimary: Colors.white,
          error: AppColors.errorRed,
        );

    final base = ThemeData.from(colorScheme: colorScheme, useMaterial3: true);

    return base.copyWith(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      extensions: [themeColors],
      dividerTheme: DividerThemeData(color: outlineSoft, thickness: 1),
      textTheme: base.textTheme.apply(bodyColor: onCard, displayColor: onCard),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevatedSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: onCard,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: onCardMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardMuted,
        labelStyle: TextStyle(color: onCardMuted),
        hintStyle: TextStyle(color: onCardMuted),
        prefixIconColor: onCardMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: resolvedAccent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: resolvedAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: resolvedAccent,
        unselectedItemColor: onCardMuted,
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        foregroundColor: onCard,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surface : const Color(0xFF26352A),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Keep darkTheme getter for any legacy call sites during migration
  static ThemeData get darkTheme =>
      buildTheme(AppColors.primaryGreen, Brightness.dark);

  static Color accentForBrightness(Color accent, Brightness brightness) {
    if (brightness == Brightness.light) return accent;

    final hsl = HSLColor.fromColor(accent);
    final lightness = (hsl.lightness * 0.68).clamp(0.28, 0.42).toDouble();
    final saturation = (hsl.saturation * 1.08).clamp(0.45, 0.95).toDouble();
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  static AppThemeColors colorsFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppThemeColors(
      card: isDark ? AppColors.cardBackground : Colors.white,
      cardMuted: isDark ? AppColors.surface : const Color(0xFFEAF0EA),
      elevatedSurface: isDark
          ? const Color(0xFF14353D)
          : const Color(0xFFFDFDF8),
      onCard: isDark ? AppColors.textPrimary : const Color(0xFF17241A),
      onCardMuted: isDark ? AppColors.textSecondary : const Color(0xFF66736A),
      outlineSoft: isDark ? const Color(0xFF2F5D6E) : const Color(0xFFD8E0D7),
      logoPlate: isDark ? const Color(0xFFDFF8EE) : const Color(0xFFF7FBF7),
      successContainer: isDark
          ? AppColors.successGreen
          : const Color(0xFFEAF6EE),
      onSuccessContainer: isDark
          ? AppColors.textPrimary
          : const Color(0xFF17391C),
    );
  }
}
