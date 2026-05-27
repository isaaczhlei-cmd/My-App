import 'package:shared_preferences/shared_preferences.dart';

/// Enum for supported booking providers.
enum BookingProvider {
  skyscanner('Skyscanner'),
  googleFlights('Google Flights'),
  kayak('Kayak');

  final String displayName;
  const BookingProvider(this.displayName);
}

/// Service for managing booking provider persistence.
///
/// Stores the user's selected booking provider to SharedPreferences
/// so the last-used provider is remembered across app sessions.
class BookingProviderService {
  static const String _storageKey = 'booking_provider';

  /// Loads the saved booking provider from SharedPreferences.
  ///
  /// Defaults to Skyscanner if no provider has been saved yet.
  ///
  /// Returns the saved [BookingProvider] or [BookingProvider.skyscanner] as default.
  static Future<BookingProvider> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved == null) {
      return BookingProvider.skyscanner;
    }

    try {
      return BookingProvider.values.firstWhere(
        (provider) => provider.name == saved,
        orElse: () => BookingProvider.skyscanner,
      );
    } catch (_) {
      return BookingProvider.skyscanner;
    }
  }

  /// Saves the selected booking provider to SharedPreferences.
  ///
  /// Persists the user's choice so it will be restored on next app launch.
  static Future<bool> setSelectedProvider(BookingProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_storageKey, provider.name);
  }

  /// Clears the saved booking provider from SharedPreferences.
  ///
  /// Useful for testing or resetting preferences.
  static Future<bool> clearProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_storageKey);
  }
}
