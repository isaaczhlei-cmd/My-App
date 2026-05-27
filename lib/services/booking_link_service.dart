import 'package:my_app/services/emissions_service.dart';

enum BookingProvider {
  skyscanner('skyscanner', 'Skyscanner'),
  googleFlights('google_flights', 'Google Flights'),
  kayak('kayak', 'Kayak');

  const BookingProvider(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static BookingProvider fromStorageValue(String? value) {
    return BookingProvider.values.firstWhere(
      (provider) => provider.storageValue == value,
      orElse: () => BookingProvider.skyscanner,
    );
  }
}

class BookingSearchRequest {
  const BookingSearchRequest({
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.passengers,
    required this.cabinClass,
    this.airlineCode,
  });

  final String origin;
  final String destination;
  final DateTime departureDate;
  final int passengers;
  final CabinClass cabinClass;
  final String? airlineCode;
}

class BookingLinkService {
  const BookingLinkService();

  Uri uriForProvider(BookingProvider provider, BookingSearchRequest request) {
    return switch (provider) {
      BookingProvider.skyscanner => skyscannerUri(request),
      BookingProvider.googleFlights => googleFlightsUri(request),
      BookingProvider.kayak => kayakUri(request),
    };
  }

  Uri skyscannerUri(BookingSearchRequest request) {
    return Uri.https(
      'www.skyscanner.net',
      '/g/referrals/v1/flights/day-view/',
      <String, String>{
        'origin': request.origin,
        'destination': request.destination,
        'outboundDate': _formatIsoDate(request.departureDate),
        'adultsv2': '${request.passengers}',
        'cabinclass': _skyscannerCabinClass(request.cabinClass),
        'market': 'US',
        'locale': 'en-US',
        'currency': 'USD',
      },
    );
  }

  Uri googleFlightsUri(BookingSearchRequest request) {
    final query = [
      request.origin,
      'to',
      request.destination,
      _formatIsoDate(request.departureDate),
      '${request.passengers}',
      request.passengers == 1 ? 'passenger' : 'passengers',
      request.cabinClass.displayName,
    ].join(' ');

    return Uri.https('www.google.com', '/travel/flights', <String, String>{
      'q': query,
    });
  }

  Uri kayakUri(BookingSearchRequest request) {
    return Uri.https(
      'www.kayak.com',
      '/flights/${request.origin}-${request.destination}/'
          '${_formatIsoDate(request.departureDate)}',
      <String, String>{
        'sort': 'bestflight_a',
        'fs': 'cabin=${_kayakCabinClass(request.cabinClass)}',
        'ucs': '${request.passengers}',
      },
    );
  }

  Uri airlineDirectUri(BookingSearchRequest request) {
    final airlineCode = request.airlineCode?.trim().toUpperCase();
    if (airlineCode == null || airlineCode.isEmpty) {
      throw ArgumentError.value(
        request.airlineCode,
        'airlineCode',
        'Airline direct booking links require an IATA airline code.',
      );
    }

    final airline = _airlineDomains[airlineCode];
    if (airline == null) {
      return Uri.https('www.google.com', '/search', <String, String>{
        'q':
            '$airlineCode direct booking ${request.origin} '
            'to ${request.destination} ${_formatIsoDate(request.departureDate)}',
      });
    }

    return Uri.https(airline.domain, airline.path, <String, String>{
      'from': request.origin,
      'to': request.destination,
      'depart': _formatIsoDate(request.departureDate),
      'adults': '${request.passengers}',
    });
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _skyscannerCabinClass(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 'economy',
      CabinClass.premiumEconomy => 'premiumeconomy',
      CabinClass.business => 'business',
      CabinClass.first => 'first',
    };
  }

  String _kayakCabinClass(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 'e',
      CabinClass.premiumEconomy => 'p',
      CabinClass.business => 'b',
      CabinClass.first => 'f',
    };
  }
}

class _AirlineBookingTarget {
  const _AirlineBookingTarget({required this.domain, required this.path});

  final String domain;
  final String path;
}

const Map<String, _AirlineBookingTarget> _airlineDomains =
    <String, _AirlineBookingTarget>{
      'AA': _AirlineBookingTarget(
        domain: 'www.aa.com',
        path: '/booking/find-flights',
      ),
      'AS': _AirlineBookingTarget(
        domain: 'www.alaskaair.com',
        path: '/shopping/flights',
      ),
      'B6': _AirlineBookingTarget(
        domain: 'www.jetblue.com',
        path: '/booking/flights',
      ),
      'DL': _AirlineBookingTarget(
        domain: 'www.delta.com',
        path: '/flight-search/book-a-flight',
      ),
      'UA': _AirlineBookingTarget(
        domain: 'www.united.com',
        path: '/en/us/fsr/choose-flights',
      ),
      'WN': _AirlineBookingTarget(
        domain: 'www.southwest.com',
        path: '/air/booking/select.html',
      ),
    };
