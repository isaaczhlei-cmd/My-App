import 'emissions_service.dart';

/// Service for building booking provider URLs for flight searches.
///
/// Provides URI builders for popular flight booking providers:
/// - Skyscanner (primary)
/// - Google Flights
/// - Kayak
///
/// Each builder accepts standardized parameters (origin, destination, dates,
/// passengers, cabin class) and returns a Uri that can be launched via url_launcher.
class BookingLinkService {
  /// Builds a Skyscanner flight search URI.
  ///
  /// Skyscanner uses the day-view endpoint with the referral API.
  ///
  /// Example:
  /// ```
  /// final uri = BookingLinkService.skyscannerUri(
  ///   origin: 'JFK',
  ///   destination: 'LAX',
  ///   departureDate: DateTime(2026, 6, 15),
  ///   passengers: 1,
  ///   cabinClass: CabinClass.economy,
  /// );
  /// ```
  static Uri skyscannerUri({
    required String origin,
    required String destination,
    required DateTime departureDate,
    required int passengers,
    required CabinClass cabinClass,
  }) {
    return Uri.https(
      'www.skyscanner.net',
      '/g/referrals/v1/flights/day-view/',
      <String, String>{
        'origin': origin,
        'destination': destination,
        'outboundDate': _formatIsoDate(departureDate),
        'adultsv2': '$passengers',
        'cabinclass': _skyscannerCabinClass(cabinClass),
        'market': 'US',
        'locale': 'en-US',
        'currency': 'USD',
      },
    );
  }

  /// Builds a Google Flights search URI.
  ///
  /// Google Flights uses the /travel/flights endpoint with query parameters.
  ///
  /// Example:
  /// ```
  /// final uri = BookingLinkService.googleFlightsUri(
  ///   origin: 'JFK',
  ///   destination: 'LAX',
  ///   departureDate: DateTime(2026, 6, 15),
  ///   passengers: 1,
  ///   cabinClass: CabinClass.economy,
  /// );
  /// ```
  static Uri googleFlightsUri({
    required String origin,
    required String destination,
    required DateTime departureDate,
    required int passengers,
    required CabinClass cabinClass,
  }) {
    // Google Flights search query format:
    // q=<departure>%20<arrival>%20<date>%20<passengers>x<cabin>
    final cabinSuffix = _googleFlightsCabinClass(cabinClass);
    final query =
        '$origin $destination ${_formatGoogleFlightsDate(departureDate)} ${passengers}x$cabinSuffix';

    return Uri.https('www.google.com', '/travel/flights', <String, String>{
      'q': query,
    });
  }

  /// Builds a Kayak flight search URI.
  ///
  /// Kayak uses the /flights endpoint with parameter encoding.
  ///
  /// Example:
  /// ```
  /// final uri = BookingLinkService.kayakUri(
  ///   origin: 'JFK',
  ///   destination: 'LAX',
  ///   departureDate: DateTime(2026, 6, 15),
  ///   passengers: 1,
  ///   cabinClass: CabinClass.economy,
  /// );
  /// ```
  static Uri kayakUri({
    required String origin,
    required String destination,
    required DateTime departureDate,
    required int passengers,
    required CabinClass cabinClass,
  }) {
    // Kayak uses a simplified format in the path-like structure:
    // /flights/<from>-<to>/<date>/<passengers>/<cabin>
    final cabin = _kayakCabinClass(cabinClass);
    final dateStr = _formatIsoDate(departureDate);

    return Uri.https(
      'www.kayak.com',
      '/flights/$origin-$destination/$dateStr/$passengers/$cabin',
    );
  }

  /// Formats a DateTime as ISO 8601 date (YYYY-MM-DD).
  static String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Formats a DateTime for Google Flights (YYYY-MM-DD).
  static String _formatGoogleFlightsDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Converts CabinClass to Skyscanner cabin class string.
  static String _skyscannerCabinClass(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 'economy',
      CabinClass.premiumEconomy => 'premiumeconomy',
      CabinClass.business => 'business',
      CabinClass.first => 'first',
    };
  }

  /// Converts CabinClass to Google Flights cabin class string.
  static String _googleFlightsCabinClass(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 'economy',
      CabinClass.premiumEconomy => 'premium',
      CabinClass.business => 'business',
      CabinClass.first => 'first',
    };
  }

  /// Converts CabinClass to Kayak cabin class string.
  static String _kayakCabinClass(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 'e',
      CabinClass.premiumEconomy => 'pe',
      CabinClass.business => 'b',
      CabinClass.first => 'f',
    };
  }
}
