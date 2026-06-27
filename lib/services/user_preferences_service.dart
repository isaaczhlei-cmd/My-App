import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'airline_directory_service.dart';
import 'emissions_service.dart';

enum Co2Unit { metricTons, kg }

extension Co2UnitDisplay on Co2Unit {
  double valueFromKg(double kg) => switch (this) {
    Co2Unit.kg => kg,
    Co2Unit.metricTons => kg / 1000,
  };

  String get shortLabel => switch (this) {
    Co2Unit.kg => 'kg',
    Co2Unit.metricTons => 't',
  };

  String get longLabel => switch (this) {
    Co2Unit.kg => 'kg',
    Co2Unit.metricTons => 'tons',
  };

  String formatKg(
    double kg, {
    int kgDecimals = 0,
    int tonDecimals = 2,
    bool includeUnit = true,
    bool compact = true,
  }) {
    final value = valueFromKg(kg);
    final decimals = this == Co2Unit.kg ? kgDecimals : tonDecimals;
    final formatted = value.toStringAsFixed(decimals);
    if (!includeUnit) return formatted;

    final unit = compact ? shortLabel : longLabel;
    return '$formatted $unit';
  }

  String formatTons(
    double tons, {
    int kgDecimals = 0,
    int tonDecimals = 2,
    bool includeUnit = true,
    bool compact = true,
  }) {
    return formatKg(
      tons * 1000,
      kgDecimals: kgDecimals,
      tonDecimals: tonDecimals,
      includeUnit: includeUnit,
      compact: compact,
    );
  }
}

enum DistanceUnit { miles, km }

class AccentPreset {
  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}

class UserPreferencesService extends ChangeNotifier {
  UserPreferencesService._();
  static final instance = UserPreferencesService._();

  static const _keyThemeMode = 'theme_mode';
  static const _keyAccentColor = 'accent_color';
  static const _keyDefaultCabinClass = 'default_cabin_class';
  static const _keyCo2Unit = 'co2_unit';
  static const _keyDistanceUnit = 'distance_unit';
  static const _keyEcoTipsEnabled = 'eco_tips_enabled';
  static const _keyTinyFlightAnimationEnabled = 'tiny_flight_animation_enabled';
  static const _keyAirplaneModeAirlineName = 'airplane_mode_airline_name';
  static const _keyAirplaneModeAirlineCode = 'airplane_mode_airline_code';
  static const _keyAirplaneModeAirlineIcao = 'airplane_mode_airline_icao';
  static const _keyAirplaneModeAirlineCountry = 'airplane_mode_airline_country';
  static const _keyWeeklyDigestEnabled = 'weekly_digest_enabled';
  static const _keyAnnualCo2GoalTons = 'annual_co2_goal_tons';

  static const List<AccentPreset> accentPresets = [
    AccentPreset('Forest', Color(0xFF64B067)),
    AccentPreset('Ocean', Color(0xFF2196F3)),
    AccentPreset('Aurora', Color(0xFF9C27B0)),
    AccentPreset('Flame', Color(0xFFFF5722)),
    AccentPreset('Arctic', Color(0xFF00BCD4)),
    AccentPreset('Ruby', Color(0xFFF44336)),
  ];

  // In-memory values (defaults applied synchronously in constructor)
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFF64B067);
  CabinClass _defaultCabinClass = CabinClass.economy;
  Co2Unit _co2Unit = Co2Unit.metricTons;
  DistanceUnit _distanceUnit = DistanceUnit.miles;
  bool _ecoTipsEnabled = true;
  bool _tinyFlightAnimationEnabled = true;
  String _airplaneModeAirlineName = 'FlightPrint Air';
  String _airplaneModeAirlineCode = 'FP';
  String _airplaneModeAirlineIcao = '';
  String _airplaneModeAirlineCountry = '';
  bool _weeklyDigestEnabled = true;
  double? _annualCo2GoalTons;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  CabinClass get defaultCabinClass => _defaultCabinClass;
  Co2Unit get co2Unit => _co2Unit;
  DistanceUnit get distanceUnit => _distanceUnit;
  bool get ecoTipsEnabled => _ecoTipsEnabled;
  bool get tinyFlightAnimationEnabled => _tinyFlightAnimationEnabled;
  String get airplaneModeAirlineName => _airplaneModeAirlineName;
  String get airplaneModeAirlineCode => _airplaneModeAirlineCode;
  String get airplaneModeAirlineIcao => _airplaneModeAirlineIcao;
  String get airplaneModeAirlineCountry => _airplaneModeAirlineCountry;
  bool get weeklyDigestEnabled => _weeklyDigestEnabled;
  double? get annualCo2GoalTons => _annualCo2GoalTons;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeStr = prefs.getString(_keyThemeMode);
    if (themeModeStr != null) {
      _themeMode = switch (themeModeStr) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    }

    final accentInt = prefs.getInt(_keyAccentColor);
    if (accentInt != null) {
      _accentColor = Color(accentInt);
    }

    final cabinStr = prefs.getString(_keyDefaultCabinClass);
    if (cabinStr != null) {
      _defaultCabinClass = switch (cabinStr) {
        'premiumEconomy' => CabinClass.premiumEconomy,
        'business' => CabinClass.business,
        'first' => CabinClass.first,
        _ => CabinClass.economy,
      };
    }

    final co2UnitStr = prefs.getString(_keyCo2Unit);
    if (co2UnitStr != null) {
      _co2Unit = co2UnitStr == 'kg' ? Co2Unit.kg : Co2Unit.metricTons;
    }

    final distUnitStr = prefs.getString(_keyDistanceUnit);
    if (distUnitStr != null) {
      _distanceUnit = distUnitStr == 'km'
          ? DistanceUnit.km
          : DistanceUnit.miles;
    }

    final ecoTips = prefs.getBool(_keyEcoTipsEnabled);
    if (ecoTips != null) _ecoTipsEnabled = ecoTips;

    final tinyFlightAnimation = prefs.getBool(_keyTinyFlightAnimationEnabled);
    if (tinyFlightAnimation != null) {
      _tinyFlightAnimationEnabled = tinyFlightAnimation;
    }

    final airplaneModeAirline = prefs.getString(_keyAirplaneModeAirlineName);
    if (airplaneModeAirline != null && airplaneModeAirline.trim().isNotEmpty) {
      _airplaneModeAirlineName = airplaneModeAirline.trim();
    }
    _airplaneModeAirlineCode =
        prefs.getString(_keyAirplaneModeAirlineCode)?.trim().toUpperCase() ??
        _airplaneModeAirlineCode;
    _airplaneModeAirlineIcao =
        prefs.getString(_keyAirplaneModeAirlineIcao)?.trim().toUpperCase() ??
        _airplaneModeAirlineIcao;
    _airplaneModeAirlineCountry =
        prefs.getString(_keyAirplaneModeAirlineCountry)?.trim() ??
        _airplaneModeAirlineCountry;

    final weeklyDigest = prefs.getBool(_keyWeeklyDigestEnabled);
    if (weeklyDigest != null) _weeklyDigestEnabled = weeklyDigest;

    final goalTons = prefs.getDouble(_keyAnnualCo2GoalTons);
    _annualCo2GoalTons = goalTons;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    });
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor, color.toARGB32());
  }

  Future<void> setDefaultCabinClass(CabinClass cabin) async {
    _defaultCabinClass = cabin;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultCabinClass, switch (cabin) {
      CabinClass.premiumEconomy => 'premiumEconomy',
      CabinClass.business => 'business',
      CabinClass.first => 'first',
      _ => 'economy',
    });
  }

  Future<void> setCo2Unit(Co2Unit unit) async {
    _co2Unit = unit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyCo2Unit,
      unit == Co2Unit.kg ? 'kg' : 'metricTons',
    );
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    _distanceUnit = unit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyDistanceUnit,
      unit == DistanceUnit.km ? 'km' : 'miles',
    );
  }

  Future<void> setEcoTipsEnabled(bool enabled) async {
    _ecoTipsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEcoTipsEnabled, enabled);
  }

  Future<void> setTinyFlightAnimationEnabled(bool enabled) async {
    _tinyFlightAnimationEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTinyFlightAnimationEnabled, enabled);
  }

  Future<void> setAirplaneModeAirlineName(String airlineName) async {
    final normalized = airlineName.trim();
    _airplaneModeAirlineName = normalized.isEmpty
        ? 'FlightPrint Air'
        : normalized;
    if (normalized.isEmpty ||
        normalized == 'flightprint Air' ||
        normalized == 'FlightPrint Air') {
      _airplaneModeAirlineCode = 'FP';
      _airplaneModeAirlineIcao = '';
      _airplaneModeAirlineCountry = '';
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyAirplaneModeAirlineName,
      _airplaneModeAirlineName,
    );
    await prefs.setString(
      _keyAirplaneModeAirlineCode,
      _airplaneModeAirlineCode,
    );
    await prefs.setString(
      _keyAirplaneModeAirlineIcao,
      _airplaneModeAirlineIcao,
    );
    await prefs.setString(
      _keyAirplaneModeAirlineCountry,
      _airplaneModeAirlineCountry,
    );
  }

  Future<void> setAirplaneModeAirline(AirlineOption airline) async {
    _airplaneModeAirlineName = airline.name.trim().isEmpty
        ? 'FlightPrint Air'
        : airline.name.trim();
    _airplaneModeAirlineCode = airline.iata.trim().isNotEmpty
        ? airline.iata.trim().toUpperCase()
        : airline.icao.trim().toUpperCase();
    _airplaneModeAirlineIcao = airline.icao.trim().toUpperCase();
    _airplaneModeAirlineCountry = airline.country.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyAirplaneModeAirlineName,
      _airplaneModeAirlineName,
    );
    await prefs.setString(
      _keyAirplaneModeAirlineCode,
      _airplaneModeAirlineCode,
    );
    await prefs.setString(
      _keyAirplaneModeAirlineIcao,
      _airplaneModeAirlineIcao,
    );
    await prefs.setString(
      _keyAirplaneModeAirlineCountry,
      _airplaneModeAirlineCountry,
    );
  }

  Future<void> setWeeklyDigestEnabled(bool enabled) async {
    _weeklyDigestEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeeklyDigestEnabled, enabled);
  }

  Future<void> setAnnualCo2GoalTons(double? tons) async {
    _annualCo2GoalTons = tons;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (tons == null) {
      await prefs.remove(_keyAnnualCo2GoalTons);
    } else {
      await prefs.setDouble(_keyAnnualCo2GoalTons, tons);
    }
  }
}
