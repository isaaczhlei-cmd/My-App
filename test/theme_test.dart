import 'package:flightprint/config/theme.dart';
import 'package:flightprint/services/user_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('uses darker selected accent colors in dark mode', () {
      for (final preset in UserPreferencesService.accentPresets) {
        final theme = AppTheme.buildTheme(preset.color, Brightness.dark);
        final primary = theme.colorScheme.primary;

        expect(
          primary.computeLuminance(),
          lessThan(preset.color.computeLuminance()),
        );
      }
    });

    test('keeps selected accent colors unchanged in light mode', () {
      for (final preset in UserPreferencesService.accentPresets) {
        final theme = AppTheme.buildTheme(preset.color, Brightness.light);

        expect(theme.colorScheme.primary, preset.color);
      }
    });
  });
}
