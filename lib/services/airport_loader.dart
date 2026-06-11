import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../screens/book_flight/airport_directory.dart';

/// Loads `assets/airports.csv` (OurAirports format) and parses it into
/// `AirportOption` instances, then registers them with
/// `AirportDirectory.setDynamicAirports(...)`.
class AirportLoader {
  /// Load the CSV from assets and register it with AirportDirectory.
  ///
  /// Returns the parsed list (may be empty). Throws on I/O/parsing errors.
  static Future<List<AirportOption>> loadAndSetFromAssets({
    String assetPath = 'assets/airports.csv',
  }) async {
    final csvString = await rootBundle.loadString(assetPath);
    final rows = const CsvToListConverter(eol: '\n').convert(csvString);
    if (rows.isEmpty) return <AirportOption>[];

    // Header row -> find indices of relevant fields.
    final header = rows.first.map((e) => e.toString()).toList();
    final idxName = header.indexOf('name');
    final idxLat = header.indexOf('latitude_deg');
    final idxLon = header.indexOf('longitude_deg');
    final idxIata = header.indexOf('iata_code');
    final idxMunicipality = header.indexOf('municipality');
    final idxCountry = header.indexOf('iso_country');

    final parsed = <AirportOption>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      try {
        final iata = (idxIata >= 0 && idxIata < row.length)
            ? row[idxIata].toString().trim()
            : '';
        if (iata.isEmpty) continue; // only include airports with IATA

        final name = (idxName >= 0 && idxName < row.length)
            ? row[idxName].toString().trim()
            : '';
        final municipality =
            (idxMunicipality >= 0 && idxMunicipality < row.length)
            ? row[idxMunicipality].toString().trim()
            : '';
        final country = (idxCountry >= 0 && idxCountry < row.length)
            ? row[idxCountry].toString().trim()
            : '';
        final lat = (idxLat >= 0 && idxLat < row.length)
            ? double.tryParse(row[idxLat].toString()) ?? 0.0
            : 0.0;
        final lon = (idxLon >= 0 && idxLon < row.length)
            ? double.tryParse(row[idxLon].toString()) ?? 0.0
            : 0.0;

        parsed.add(
          AirportOption(
            code: iata.toUpperCase(),
            city: municipality.isNotEmpty
                ? municipality
                : (name.isNotEmpty ? name : ''),
            name: name,
            country: country,
            latitude: lat,
            longitude: lon,
          ),
        );
      } catch (_) {
        // skip malformed rows
        continue;
      }
    }

    // Register with AirportDirectory so searches use the dynamic dataset.
    AirportDirectory.setDynamicAirports(parsed);
    return parsed;
  }
}
