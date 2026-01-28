import 'package:flutter/material.dart';

class AppTheme {
  // Colors from mockup
  static const Color primaryGreen = Color.fromARGB(255, 100, 176, 103);
  static const Color darkBackground = Color(0xFF0D1B2A);
  static const Color cardBackground = Color(0xFF1B2838);
  static const Color surfaceColor = Color(0xFF243447);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: primaryGreen,
        surface: cardBackground,
        error: Color(0xFFE57373),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
      ),
    );
  }
}
