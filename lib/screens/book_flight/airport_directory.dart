class AirportOption {
  const AirportOption({
    required this.code,
    required this.city,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String code;
  final String city;
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  String get shortLabel => '$city ($code)';
  String get fullLabel => '$city ($code) - $name';
}

class AirportDirectory {
  static const List<AirportOption> airports = [
    AirportOption(code: 'JFK', city: 'New York', name: 'John F. Kennedy International Airport', country: 'United States', latitude: 40.6413, longitude: -73.7781),
    AirportOption(code: 'LGA', city: 'New York', name: 'LaGuardia Airport', country: 'United States', latitude: 40.7769, longitude: -73.8740),
    AirportOption(code: 'EWR', city: 'Newark', name: 'Newark Liberty International Airport', country: 'United States', latitude: 40.6895, longitude: -74.1745),
    AirportOption(code: 'LAX', city: 'Los Angeles', name: 'Los Angeles International Airport', country: 'United States', latitude: 33.9416, longitude: -118.4085),
    AirportOption(code: 'SFO', city: 'San Francisco', name: 'San Francisco International Airport', country: 'United States', latitude: 37.6213, longitude: -122.3790),
    AirportOption(code: 'SEA', city: 'Seattle', name: 'Seattle-Tacoma International Airport', country: 'United States', latitude: 47.4502, longitude: -122.3088),
    AirportOption(code: 'ORD', city: 'Chicago', name: 'O Hare International Airport', country: 'United States', latitude: 41.9742, longitude: -87.9073),
    AirportOption(code: 'BOS', city: 'Boston', name: 'Logan International Airport', country: 'United States', latitude: 42.3656, longitude: -71.0096),
    AirportOption(code: 'AUS', city: 'Austin', name: 'Austin-Bergstrom International Airport', country: 'United States', latitude: 30.1975, longitude: -97.6664),
    AirportOption(code: 'MIA', city: 'Miami', name: 'Miami International Airport', country: 'United States', latitude: 25.7959, longitude: -80.2870),
    AirportOption(code: 'ATL', city: 'Atlanta', name: 'Hartsfield-Jackson Atlanta International Airport', country: 'United States', latitude: 33.6407, longitude: -84.4277),
    AirportOption(code: 'DFW', city: 'Dallas', name: 'Dallas Fort Worth International Airport', country: 'United States', latitude: 32.8998, longitude: -97.0403),
    AirportOption(code: 'DEN', city: 'Denver', name: 'Denver International Airport', country: 'United States', latitude: 39.8561, longitude: -104.6737),
    AirportOption(code: 'LAS', city: 'Las Vegas', name: 'Harry Reid International Airport', country: 'United States', latitude: 36.0840, longitude: -115.1537),
    AirportOption(code: 'PHX', city: 'Phoenix', name: 'Phoenix Sky Harbor International Airport', country: 'United States', latitude: 33.4373, longitude: -112.0078),
    AirportOption(code: 'IAD', city: 'Washington', name: 'Washington Dulles International Airport', country: 'United States', latitude: 38.9531, longitude: -77.4565),
    AirportOption(code: 'YYZ', city: 'Toronto', name: 'Toronto Pearson International Airport', country: 'Canada', latitude: 43.6777, longitude: -79.6248),
    AirportOption(code: 'YVR', city: 'Vancouver', name: 'Vancouver International Airport', country: 'Canada', latitude: 49.1967, longitude: -123.1815),
    AirportOption(code: 'YUL', city: 'Montreal', name: 'Montreal-Trudeau International Airport', country: 'Canada', latitude: 45.4706, longitude: -73.7408),
    AirportOption(code: 'MEX', city: 'Mexico City', name: 'Benito Juarez International Airport', country: 'Mexico', latitude: 19.4361, longitude: -99.0719),
    AirportOption(code: 'CUN', city: 'Cancun', name: 'Cancun International Airport', country: 'Mexico', latitude: 21.0365, longitude: -86.8771),
    AirportOption(code: 'GRU', city: 'Sao Paulo', name: 'Guarulhos International Airport', country: 'Brazil', latitude: -23.4356, longitude: -46.4731),
    AirportOption(code: 'GIG', city: 'Rio de Janeiro', name: 'Galeao International Airport', country: 'Brazil', latitude: -22.8090, longitude: -43.2506),
    AirportOption(code: 'EZE', city: 'Buenos Aires', name: 'Ezeiza International Airport', country: 'Argentina', latitude: -34.8222, longitude: -58.5358),
    AirportOption(code: 'SCL', city: 'Santiago', name: 'Arturo Merino Benitez Airport', country: 'Chile', latitude: -33.3929, longitude: -70.7858),
    AirportOption(code: 'LHR', city: 'London', name: 'Heathrow Airport', country: 'United Kingdom', latitude: 51.4700, longitude: -0.4543),
    AirportOption(code: 'LGW', city: 'London', name: 'Gatwick Airport', country: 'United Kingdom', latitude: 51.1537, longitude: -0.1821),
    AirportOption(code: 'CDG', city: 'Paris', name: 'Charles de Gaulle Airport', country: 'France', latitude: 49.0097, longitude: 2.5479),
    AirportOption(code: 'ORY', city: 'Paris', name: 'Orly Airport', country: 'France', latitude: 48.7262, longitude: 2.3652),
    AirportOption(code: 'AMS', city: 'Amsterdam', name: 'Amsterdam Airport Schiphol', country: 'Netherlands', latitude: 52.3105, longitude: 4.7683),
    AirportOption(code: 'FRA', city: 'Frankfurt', name: 'Frankfurt Airport', country: 'Germany', latitude: 50.0379, longitude: 8.5622),
    AirportOption(code: 'MUC', city: 'Munich', name: 'Munich Airport', country: 'Germany', latitude: 48.3538, longitude: 11.7861),
    AirportOption(code: 'MAD', city: 'Madrid', name: 'Adolfo Suarez Madrid-Barajas Airport', country: 'Spain', latitude: 40.4983, longitude: -3.5676),
    AirportOption(code: 'BCN', city: 'Barcelona', name: 'Barcelona-El Prat Airport', country: 'Spain', latitude: 41.2974, longitude: 2.0833),
    AirportOption(code: 'FCO', city: 'Rome', name: 'Leonardo da Vinci Fiumicino Airport', country: 'Italy', latitude: 41.8003, longitude: 12.2389),
    AirportOption(code: 'ZRH', city: 'Zurich', name: 'Zurich Airport', country: 'Switzerland', latitude: 47.4581, longitude: 8.5555),
    AirportOption(code: 'VIE', city: 'Vienna', name: 'Vienna International Airport', country: 'Austria', latitude: 48.1103, longitude: 16.5697),
    AirportOption(code: 'CPH', city: 'Copenhagen', name: 'Copenhagen Airport', country: 'Denmark', latitude: 55.6181, longitude: 12.6560),
    AirportOption(code: 'OSL', city: 'Oslo', name: 'Oslo Airport', country: 'Norway', latitude: 60.1976, longitude: 11.1004),
    AirportOption(code: 'ARN', city: 'Stockholm', name: 'Stockholm Arlanda Airport', country: 'Sweden', latitude: 59.6498, longitude: 17.9238),
    AirportOption(code: 'HEL', city: 'Helsinki', name: 'Helsinki Airport', country: 'Finland', latitude: 60.3172, longitude: 24.9633),
    AirportOption(code: 'DUB', city: 'Dublin', name: 'Dublin Airport', country: 'Ireland', latitude: 53.4213, longitude: -6.2701),
    AirportOption(code: 'IST', city: 'Istanbul', name: 'Istanbul Airport', country: 'Turkey', latitude: 41.2753, longitude: 28.7519),
    AirportOption(code: 'ATH', city: 'Athens', name: 'Athens International Airport', country: 'Greece', latitude: 37.9364, longitude: 23.9475),
    AirportOption(code: 'PRG', city: 'Prague', name: 'Vaclav Havel Airport Prague', country: 'Czech Republic', latitude: 50.1008, longitude: 14.2600),
    AirportOption(code: 'WAW', city: 'Warsaw', name: 'Warsaw Chopin Airport', country: 'Poland', latitude: 52.1657, longitude: 20.9671),
    AirportOption(code: 'DXB', city: 'Dubai', name: 'Dubai International Airport', country: 'United Arab Emirates', latitude: 25.2532, longitude: 55.3657),
    AirportOption(code: 'DOH', city: 'Doha', name: 'Hamad International Airport', country: 'Qatar', latitude: 25.2731, longitude: 51.6080),
    AirportOption(code: 'AUH', city: 'Abu Dhabi', name: 'Zayed International Airport', country: 'United Arab Emirates', latitude: 24.4330, longitude: 54.6511),
    AirportOption(code: 'RUH', city: 'Riyadh', name: 'King Khalid International Airport', country: 'Saudi Arabia', latitude: 24.9576, longitude: 46.6988),
    AirportOption(code: 'JED', city: 'Jeddah', name: 'King Abdulaziz International Airport', country: 'Saudi Arabia', latitude: 21.6702, longitude: 39.1525),
    AirportOption(code: 'TLV', city: 'Tel Aviv', name: 'Ben Gurion Airport', country: 'Israel', latitude: 32.0005, longitude: 34.8708),
    AirportOption(code: 'CAI', city: 'Cairo', name: 'Cairo International Airport', country: 'Egypt', latitude: 30.1219, longitude: 31.4056),
    AirportOption(code: 'JNB', city: 'Johannesburg', name: 'O. R. Tambo International Airport', country: 'South Africa', latitude: -26.1337, longitude: 28.2420),
    AirportOption(code: 'CPT', city: 'Cape Town', name: 'Cape Town International Airport', country: 'South Africa', latitude: -33.9700, longitude: 18.6021),
    AirportOption(code: 'NBO', city: 'Nairobi', name: 'Jomo Kenyatta International Airport', country: 'Kenya', latitude: -1.3192, longitude: 36.9278),
    AirportOption(code: 'ADD', city: 'Addis Ababa', name: 'Bole International Airport', country: 'Ethiopia', latitude: 8.9779, longitude: 38.7993),
    AirportOption(code: 'CMN', city: 'Casablanca', name: 'Mohammed V International Airport', country: 'Morocco', latitude: 33.3675, longitude: -7.5899),
    AirportOption(code: 'LOS', city: 'Lagos', name: 'Murtala Muhammed International Airport', country: 'Nigeria', latitude: 6.5774, longitude: 3.3212),
    AirportOption(code: 'BOM', city: 'Mumbai', name: 'Chhatrapati Shivaji Maharaj International Airport', country: 'India', latitude: 19.0896, longitude: 72.8656),
    AirportOption(code: 'DEL', city: 'Delhi', name: 'Indira Gandhi International Airport', country: 'India', latitude: 28.5562, longitude: 77.1000),
    AirportOption(code: 'BLR', city: 'Bengaluru', name: 'Kempegowda International Airport', country: 'India', latitude: 13.1986, longitude: 77.7066),
    AirportOption(code: 'SIN', city: 'Singapore', name: 'Singapore Changi Airport', country: 'Singapore', latitude: 1.3644, longitude: 103.9915),
    AirportOption(code: 'BKK', city: 'Bangkok', name: 'Suvarnabhumi Airport', country: 'Thailand', latitude: 13.6900, longitude: 100.7501),
    AirportOption(code: 'HKT', city: 'Phuket', name: 'Phuket International Airport', country: 'Thailand', latitude: 8.1132, longitude: 98.3169),
    AirportOption(code: 'KUL', city: 'Kuala Lumpur', name: 'Kuala Lumpur International Airport', country: 'Malaysia', latitude: 2.7456, longitude: 101.7072),
    AirportOption(code: 'CGK', city: 'Jakarta', name: 'Soekarno-Hatta International Airport', country: 'Indonesia', latitude: -6.1256, longitude: 106.6559),
    AirportOption(code: 'MNL', city: 'Manila', name: 'Ninoy Aquino International Airport', country: 'Philippines', latitude: 14.5086, longitude: 121.0198),
    AirportOption(code: 'HKG', city: 'Hong Kong', name: 'Hong Kong International Airport', country: 'Hong Kong', latitude: 22.3080, longitude: 113.9185),
    AirportOption(code: 'TPE', city: 'Taipei', name: 'Taiwan Taoyuan International Airport', country: 'Taiwan', latitude: 25.0797, longitude: 121.2342),
    AirportOption(code: 'ICN', city: 'Seoul', name: 'Incheon International Airport', country: 'South Korea', latitude: 37.4602, longitude: 126.4407),
    AirportOption(code: 'GMP', city: 'Seoul', name: 'Gimpo International Airport', country: 'South Korea', latitude: 37.5583, longitude: 126.7906),
    AirportOption(code: 'NRT', city: 'Tokyo', name: 'Narita International Airport', country: 'Japan', latitude: 35.7720, longitude: 140.3929),
    AirportOption(code: 'HND', city: 'Tokyo', name: 'Haneda Airport', country: 'Japan', latitude: 35.5494, longitude: 139.7798),
    AirportOption(code: 'KIX', city: 'Osaka', name: 'Kansai International Airport', country: 'Japan', latitude: 34.4347, longitude: 135.2440),
    AirportOption(code: 'PEK', city: 'Beijing', name: 'Beijing Capital International Airport', country: 'China', latitude: 40.0799, longitude: 116.6031),
    AirportOption(code: 'PKX', city: 'Beijing', name: 'Beijing Daxing International Airport', country: 'China', latitude: 39.5098, longitude: 116.4105),
    AirportOption(code: 'PVG', city: 'Shanghai', name: 'Shanghai Pudong International Airport', country: 'China', latitude: 31.1443, longitude: 121.8083),
    AirportOption(code: 'CAN', city: 'Guangzhou', name: 'Guangzhou Baiyun International Airport', country: 'China', latitude: 23.3924, longitude: 113.2988),
    AirportOption(code: 'SZX', city: 'Shenzhen', name: 'Shenzhen Baoan International Airport', country: 'China', latitude: 22.6393, longitude: 113.8107),
    AirportOption(code: 'SYD', city: 'Sydney', name: 'Sydney Airport', country: 'Australia', latitude: -33.9399, longitude: 151.1753),
    AirportOption(code: 'MEL', city: 'Melbourne', name: 'Melbourne Airport', country: 'Australia', latitude: -37.6690, longitude: 144.8410),
    AirportOption(code: 'BNE', city: 'Brisbane', name: 'Brisbane Airport', country: 'Australia', latitude: -27.3842, longitude: 153.1175),
    AirportOption(code: 'PER', city: 'Perth', name: 'Perth Airport', country: 'Australia', latitude: -31.9403, longitude: 115.9672),
    AirportOption(code: 'AKL', city: 'Auckland', name: 'Auckland Airport', country: 'New Zealand', latitude: -37.0082, longitude: 174.7850),
    AirportOption(code: 'CHC', city: 'Christchurch', name: 'Christchurch Airport', country: 'New Zealand', latitude: -43.4894, longitude: 172.5322),
  ];

  static List<AirportOption> search(String query, {String? excludeCode}) {
    final normalized = query.trim().toLowerCase();
    final results = airports.where((airport) {
      if (excludeCode != null && airport.code == excludeCode) {
        return false;
      }
      if (normalized.isEmpty) {
        return true;
      }
      final haystack = [
        airport.code,
        airport.city,
        airport.name,
        airport.country,
        airport.shortLabel,
        airport.fullLabel,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();

    results.sort((a, b) {
      final aStarts = a.code.toLowerCase().startsWith(normalized) ||
          a.city.toLowerCase().startsWith(normalized);
      final bStarts = b.code.toLowerCase().startsWith(normalized) ||
          b.city.toLowerCase().startsWith(normalized);
      if (aStarts != bStarts) {
        return aStarts ? -1 : 1;
      }
      return a.city.compareTo(b.city);
    });

    return results.take(8).toList();
  }

  static AirportOption? findBestMatch(String query, {String? excludeCode}) {
    final normalized = query.trim().toLowerCase();
    for (final airport in airports) {
      if (excludeCode != null && airport.code == excludeCode) {
        continue;
      }
      if (airport.code.toLowerCase() == normalized ||
          airport.shortLabel.toLowerCase() == normalized ||
          airport.fullLabel.toLowerCase() == normalized) {
        return airport;
      }
    }
    final matches = search(query, excludeCode: excludeCode);
    return matches.isEmpty ? null : matches.first;
  }
}
