import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emissions_service.dart';

enum Co2Unit { metricTons, kg }

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
  bool _weeklyDigestEnabled = true;
  double? _annualCo2GoalTons;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  CabinClass get defaultCabinClass => _defaultCabinClass;
  Co2Unit get co2Unit => _co2Unit;
  DistanceUnit get distanceUnit => _distanceUnit;
  bool get ecoTipsEnabled => _ecoTipsEnabled;
  bool get tinyFlightAnimationEnabled => _tinyFlightAnimationEnabled;
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
