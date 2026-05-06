class FlightCatalogEntry {
  const FlightCatalogEntry({
    required this.airlineName,
    required this.carrierCode,
    required this.flightNumber,
    required this.originCode,
    required this.destinationCode,
    required this.originCity,
    required this.destinationCity,
    this.isFeatured = false,
  });

  final String airlineName;
  final String carrierCode;
  final int flightNumber;
  final String originCode;
  final String destinationCode;
  final String originCity;
  final String destinationCity;
  final bool isFeatured;

  String get id =>
      '${carrierCode}_${flightNumber}_${originCode}_$destinationCode';
  String get flightCode => '$carrierCode $flightNumber';
  String get compactFlightCode => '$carrierCode$flightNumber';
  String get routeCodeLabel => '$originCode -> $destinationCode';
  String get routeCityLabel => '$originCity to $destinationCity';
}

class FlightCatalog {
  static const List<FlightCatalogEntry> entries = [
    FlightCatalogEntry(
      airlineName: 'United',
      carrierCode: 'UA',
      flightNumber: 857,
      originCode: 'SFO',
      destinationCode: 'JFK',
      originCity: 'San Francisco',
      destinationCity: 'New York',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'United',
      carrierCode: 'UA',
      flightNumber: 110,
      originCode: 'LAX',
      destinationCode: 'ORD',
      originCity: 'Los Angeles',
      destinationCity: 'Chicago',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'United',
      carrierCode: 'UA',
      flightNumber: 915,
      originCode: 'IAD',
      destinationCode: 'LHR',
      originCity: 'Washington',
      destinationCity: 'London',
    ),
    FlightCatalogEntry(
      airlineName: 'United',
      carrierCode: 'UA',
      flightNumber: 34,
      originCode: 'EWR',
      destinationCode: 'LAX',
      originCity: 'Newark',
      destinationCity: 'Los Angeles',
    ),
    FlightCatalogEntry(
      airlineName: 'United',
      carrierCode: 'UA',
      flightNumber: 199,
      originCode: 'DEN',
      destinationCode: 'SEA',
      originCity: 'Denver',
      destinationCity: 'Seattle',
    ),
    FlightCatalogEntry(
      airlineName: 'Delta',
      carrierCode: 'DL',
      flightNumber: 289,
      originCode: 'JFK',
      destinationCode: 'LAX',
      originCity: 'New York',
      destinationCity: 'Los Angeles',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Delta',
      carrierCode: 'DL',
      flightNumber: 117,
      originCode: 'SEA',
      destinationCode: 'ATL',
      originCity: 'Seattle',
      destinationCity: 'Atlanta',
    ),
    FlightCatalogEntry(
      airlineName: 'Delta',
      carrierCode: 'DL',
      flightNumber: 48,
      originCode: 'BOS',
      destinationCode: 'AMS',
      originCity: 'Boston',
      destinationCity: 'Amsterdam',
    ),
    FlightCatalogEntry(
      airlineName: 'Delta',
      carrierCode: 'DL',
      flightNumber: 62,
      originCode: 'LAX',
      destinationCode: 'SYD',
      originCity: 'Los Angeles',
      destinationCity: 'Sydney',
    ),
    FlightCatalogEntry(
      airlineName: 'Delta',
      carrierCode: 'DL',
      flightNumber: 205,
      originCode: 'SFO',
      destinationCode: 'SEA',
      originCity: 'San Francisco',
      destinationCity: 'Seattle',
    ),
    FlightCatalogEntry(
      airlineName: 'American',
      carrierCode: 'AA',
      flightNumber: 12,
      originCode: 'JFK',
      destinationCode: 'LAX',
      originCity: 'New York',
      destinationCity: 'Los Angeles',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'American',
      carrierCode: 'AA',
      flightNumber: 72,
      originCode: 'ORD',
      destinationCode: 'LHR',
      originCity: 'Chicago',
      destinationCity: 'London',
    ),
    FlightCatalogEntry(
      airlineName: 'American',
      carrierCode: 'AA',
      flightNumber: 145,
      originCode: 'DFW',
      destinationCode: 'MIA',
      originCity: 'Dallas',
      destinationCity: 'Miami',
    ),
    FlightCatalogEntry(
      airlineName: 'American',
      carrierCode: 'AA',
      flightNumber: 204,
      originCode: 'PHX',
      destinationCode: 'JFK',
      originCity: 'Phoenix',
      destinationCity: 'New York',
    ),
    FlightCatalogEntry(
      airlineName: 'American',
      carrierCode: 'AA',
      flightNumber: 169,
      originCode: 'LAX',
      destinationCode: 'NRT',
      originCity: 'Los Angeles',
      destinationCity: 'Tokyo',
    ),
    FlightCatalogEntry(
      airlineName: 'Alaska',
      carrierCode: 'AS',
      flightNumber: 331,
      originCode: 'SEA',
      destinationCode: 'SFO',
      originCity: 'Seattle',
      destinationCity: 'San Francisco',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Alaska',
      carrierCode: 'AS',
      flightNumber: 143,
      originCode: 'LAX',
      destinationCode: 'SEA',
      originCity: 'Los Angeles',
      destinationCity: 'Seattle',
    ),
    FlightCatalogEntry(
      airlineName: 'Alaska',
      carrierCode: 'AS',
      flightNumber: 811,
      originCode: 'SFO',
      destinationCode: 'AUS',
      originCity: 'San Francisco',
      destinationCity: 'Austin',
    ),
    FlightCatalogEntry(
      airlineName: 'Southwest',
      carrierCode: 'WN',
      flightNumber: 2211,
      originCode: 'AUS',
      destinationCode: 'DEN',
      originCity: 'Austin',
      destinationCity: 'Denver',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Southwest',
      carrierCode: 'WN',
      flightNumber: 115,
      originCode: 'LAS',
      destinationCode: 'PHX',
      originCity: 'Las Vegas',
      destinationCity: 'Phoenix',
    ),
    FlightCatalogEntry(
      airlineName: 'Southwest',
      carrierCode: 'WN',
      flightNumber: 640,
      originCode: 'DEN',
      destinationCode: 'ORD',
      originCity: 'Denver',
      destinationCity: 'Chicago',
    ),
    FlightCatalogEntry(
      airlineName: 'Southwest',
      carrierCode: 'WN',
      flightNumber: 902,
      originCode: 'ATL',
      destinationCode: 'MIA',
      originCity: 'Atlanta',
      destinationCity: 'Miami',
    ),
    FlightCatalogEntry(
      airlineName: 'JetBlue',
      carrierCode: 'B6',
      flightNumber: 23,
      originCode: 'JFK',
      destinationCode: 'LAX',
      originCity: 'New York',
      destinationCity: 'Los Angeles',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'JetBlue',
      carrierCode: 'B6',
      flightNumber: 415,
      originCode: 'BOS',
      destinationCode: 'SFO',
      originCity: 'Boston',
      destinationCity: 'San Francisco',
    ),
    FlightCatalogEntry(
      airlineName: 'JetBlue',
      carrierCode: 'B6',
      flightNumber: 189,
      originCode: 'JFK',
      destinationCode: 'SEA',
      originCity: 'New York',
      destinationCity: 'Seattle',
    ),
    FlightCatalogEntry(
      airlineName: 'Lufthansa',
      carrierCode: 'LH',
      flightNumber: 401,
      originCode: 'JFK',
      destinationCode: 'FRA',
      originCity: 'New York',
      destinationCity: 'Frankfurt',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Lufthansa',
      carrierCode: 'LH',
      flightNumber: 453,
      originCode: 'LAX',
      destinationCode: 'MUC',
      originCity: 'Los Angeles',
      destinationCity: 'Munich',
    ),
    FlightCatalogEntry(
      airlineName: 'British Airways',
      carrierCode: 'BA',
      flightNumber: 178,
      originCode: 'JFK',
      destinationCode: 'LHR',
      originCity: 'New York',
      destinationCity: 'London',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'British Airways',
      carrierCode: 'BA',
      flightNumber: 286,
      originCode: 'SFO',
      destinationCode: 'LHR',
      originCity: 'San Francisco',
      destinationCity: 'London',
    ),
    FlightCatalogEntry(
      airlineName: 'British Airways',
      carrierCode: 'BA',
      flightNumber: 268,
      originCode: 'LAX',
      destinationCode: 'LHR',
      originCity: 'Los Angeles',
      destinationCity: 'London',
    ),
    FlightCatalogEntry(
      airlineName: 'Air France',
      carrierCode: 'AF',
      flightNumber: 23,
      originCode: 'LAX',
      destinationCode: 'CDG',
      originCity: 'Los Angeles',
      destinationCity: 'Paris',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Air France',
      carrierCode: 'AF',
      flightNumber: 11,
      originCode: 'JFK',
      destinationCode: 'CDG',
      originCity: 'New York',
      destinationCity: 'Paris',
    ),
    FlightCatalogEntry(
      airlineName: 'Emirates',
      carrierCode: 'EK',
      flightNumber: 202,
      originCode: 'JFK',
      destinationCode: 'DXB',
      originCity: 'New York',
      destinationCity: 'Dubai',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Emirates',
      carrierCode: 'EK',
      flightNumber: 216,
      originCode: 'LAX',
      destinationCode: 'DXB',
      originCity: 'Los Angeles',
      destinationCity: 'Dubai',
    ),
    FlightCatalogEntry(
      airlineName: 'Qatar Airways',
      carrierCode: 'QR',
      flightNumber: 744,
      originCode: 'JFK',
      destinationCode: 'DOH',
      originCity: 'New York',
      destinationCity: 'Doha',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Qatar Airways',
      carrierCode: 'QR',
      flightNumber: 739,
      originCode: 'LAX',
      destinationCode: 'DOH',
      originCity: 'Los Angeles',
      destinationCity: 'Doha',
    ),
    FlightCatalogEntry(
      airlineName: 'Cathay Pacific Airways',
      carrierCode: 'CX',
      flightNumber: 881,
      originCode: 'LAX',
      destinationCode: 'HKG',
      originCity: 'Los Angeles',
      destinationCity: 'Hong Kong',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Air Canada',
      carrierCode: 'AC',
      flightNumber: 758,
      originCode: 'SFO',
      destinationCode: 'YYZ',
      originCity: 'San Francisco',
      destinationCity: 'Toronto',
    ),
    FlightCatalogEntry(
      airlineName: 'Air Canada',
      carrierCode: 'AC',
      flightNumber: 43,
      originCode: 'YYZ',
      destinationCode: 'DEL',
      originCity: 'Toronto',
      destinationCity: 'Delhi',
    ),
    FlightCatalogEntry(
      airlineName: 'Singapore Airlines',
      carrierCode: 'SQ',
      flightNumber: 33,
      originCode: 'SFO',
      destinationCode: 'SIN',
      originCity: 'San Francisco',
      destinationCity: 'Singapore',
      isFeatured: true,
    ),
    FlightCatalogEntry(
      airlineName: 'Singapore Airlines',
      carrierCode: 'SQ',
      flightNumber: 12,
      originCode: 'NRT',
      destinationCode: 'LAX',
      originCity: 'Tokyo',
      destinationCity: 'Los Angeles',
    ),
    FlightCatalogEntry(
      airlineName: 'ANA',
      carrierCode: 'NH',
      flightNumber: 7,
      originCode: 'LAX',
      destinationCode: 'NRT',
      originCity: 'Los Angeles',
      destinationCity: 'Tokyo',
    ),
    FlightCatalogEntry(
      airlineName: 'ANA',
      carrierCode: 'NH',
      flightNumber: 113,
      originCode: 'HND',
      destinationCode: 'SFO',
      originCity: 'Tokyo',
      destinationCity: 'San Francisco',
    ),
  ];

  static List<String> airlineOptions() {
    final airlines = entries.map((entry) => entry.airlineName).toSet().toList()
      ..sort();
    return airlines;
  }

  static List<FlightCatalogEntry> featured({
    String? airlineName,
    int limit = 12,
    Set<String> hiddenEntryIds = const {},
  }) {
    var featuredEntries = entries.where((entry) {
      if (hiddenEntryIds.contains(entry.id)) return false;
      if (!entry.isFeatured) return false;
      if (airlineName == null) return true;
      return entry.airlineName == airlineName;
    }).toList()..sort((a, b) => a.flightCode.compareTo(b.flightCode));

    if (featuredEntries.isEmpty && airlineName != null) {
      featuredEntries =
          entries
              .where(
                (entry) =>
                    entry.airlineName == airlineName &&
                    !hiddenEntryIds.contains(entry.id),
              )
              .toList()
            ..sort((a, b) => a.flightCode.compareTo(b.flightCode));
    }

    return featuredEntries.take(limit).toList();
  }

  static List<FlightCatalogEntry> search(
    String query, {
    String? airlineName,
    int limit = 12,
    Set<String> hiddenEntryIds = const {},
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return featured(
        airlineName: airlineName,
        limit: limit,
        hiddenEntryIds: hiddenEntryIds,
      );
    }

    final scoredEntries = <({FlightCatalogEntry entry, int score})>[];
    for (final entry in entries) {
      if (hiddenEntryIds.contains(entry.id)) {
        continue;
      }
      if (airlineName != null && entry.airlineName != airlineName) {
        continue;
      }
      final score = _scoreEntry(entry, normalized);
      if (score > 0) {
        scoredEntries.add((entry: entry, score: score));
      }
    }

    scoredEntries.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      if (a.entry.isFeatured != b.entry.isFeatured) {
        return a.entry.isFeatured ? -1 : 1;
      }
      return a.entry.flightCode.compareTo(b.entry.flightCode);
    });

    return scoredEntries.take(limit).map((item) => item.entry).toList();
  }

  static int _scoreEntry(FlightCatalogEntry entry, String normalizedQuery) {
    final compactQuery = normalizedQuery.replaceAll(' ', '');
    final flightCode = entry.flightCode.toLowerCase();
    final compactFlightCode = entry.compactFlightCode.toLowerCase();
    final airline = entry.airlineName.toLowerCase();
    final carrier = entry.carrierCode.toLowerCase();
    final originCode = entry.originCode.toLowerCase();
    final destinationCode = entry.destinationCode.toLowerCase();
    final originCity = entry.originCity.toLowerCase();
    final destinationCity = entry.destinationCity.toLowerCase();
    final route =
        '${entry.originCode} ${entry.destinationCode} ${entry.originCity} ${entry.destinationCity}'
            .toLowerCase();

    if (compactFlightCode == compactQuery || flightCode == normalizedQuery) {
      return 400;
    }
    if (compactFlightCode.startsWith(compactQuery) ||
        flightCode.startsWith(normalizedQuery)) {
      return 320;
    }
    if (airline.startsWith(normalizedQuery) ||
        carrier.startsWith(normalizedQuery)) {
      return 240;
    }
    if (originCode.startsWith(normalizedQuery) ||
        destinationCode.startsWith(normalizedQuery) ||
        originCity.startsWith(normalizedQuery) ||
        destinationCity.startsWith(normalizedQuery)) {
      return 200;
    }
    if (route.contains(normalizedQuery)) {
      return 150;
    }
    if (airline.contains(normalizedQuery) ||
        carrier.contains(normalizedQuery)) {
      return 120;
    }
    return 0;
  }
}
