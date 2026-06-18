import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

class AirlineOption {
  const AirlineOption({
    required this.name,
    required this.country,
    required this.iata,
    required this.icao,
    required this.active,
  });

  final String name;
  final String country;
  final String iata;
  final String icao;
  final bool active;

  String get searchText => '$name $country $iata $icao'.toLowerCase();
  String get initial {
    final first = name.trim().isEmpty ? '#' : name.trim()[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
  }
}

class AirlineDirectoryService {
  AirlineDirectoryService._();
  static final instance = AirlineDirectoryService._();

  List<AirlineOption>? _cache;

  Future<List<AirlineOption>> loadAirlines() async {
    if (_cache case final cached?) return cached;

    final csvString = await rootBundle.loadString('assets/airlines.csv');
    final rows = const CsvToListConverter(eol: '\n').convert(csvString);
    final airlines = <AirlineOption>[];

    for (final row in rows.skip(1)) {
      if (row.isEmpty) continue;
      final name = _cell(row, 0);
      if (name.isEmpty) continue;
      airlines.add(
        AirlineOption(
          name: name,
          country: _cell(row, 4),
          iata: _cell(row, 2),
          icao: _cell(row, 3),
          active: _cell(row, 5).toUpperCase() == 'Y',
        ),
      );
    }

    airlines.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _cache = airlines;
    return airlines;
  }

  static String _cell(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return row[index].toString().trim();
  }
}
