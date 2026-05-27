import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/emissions_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../add_flight/flight_catalog.dart';
import 'airport_directory.dart';

class BookFlightScreen extends StatefulWidget {
  const BookFlightScreen({super.key});

  @override
  State<BookFlightScreen> createState() => _BookFlightScreenState();
}

class _BookFlightScreenState extends State<BookFlightScreen> {
  AirportOption _fromAirport = AirportDirectory.airports.firstWhere(
    (airport) => airport.code == 'JFK',
  );
  AirportOption _toAirport = AirportDirectory.airports.firstWhere(
    (airport) => airport.code == 'LAX',
  );
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();
  List<AirportOption> _fromMatches = const [];
  List<AirportOption> _toMatches = const [];
  late DateTime _departDate;
  int _passengers = 1;
  CabinClass _selectedCabin = CabinClass.economy;
  List<_FlightSearchResult> _results = const [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _departDate = today.add(const Duration(days: 14));
    _fromController = TextEditingController(text: _fromAirport.shortLabel);
    _toController = TextEditingController(text: _toAirport.shortLabel);
    _fromFocusNode.addListener(_handleFocusChange);
    _toFocusNode.addListener(_handleFocusChange);
    _runSearch(showErrors: false);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _toFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_fromFocusNode.hasFocus && _fromMatches.isNotEmpty) {
      setState(() => _fromMatches = const []);
    }
    if (!_toFocusNode.hasFocus && _toMatches.isNotEmpty) {
      setState(() => _toMatches = const []);
    }
  }

  void _updateAirportMatches(String query, {required bool isFrom}) {
    final matches = AirportDirectory.search(
      query,
      excludeCode: isFrom ? _toAirport.code : _fromAirport.code,
    );
    setState(() {
      if (isFrom) {
        _fromMatches = matches;
      } else {
        _toMatches = matches;
      }
    });
  }

  void _selectAirport(AirportOption airport, {required bool isFrom}) {
    setState(() {
      if (isFrom) {
        _fromAirport = airport;
        _fromController.text = airport.shortLabel;
        _fromMatches = const [];
        _fromFocusNode.unfocus();
      } else {
        _toAirport = airport;
        _toController.text = airport.shortLabel;
        _toMatches = const [];
        _toFocusNode.unfocus();
      }
    });
  }

  void _swapAirports() {
    setState(() {
      final originalFrom = _fromAirport;
      _fromAirport = _toAirport;
      _toAirport = originalFrom;
      _fromController.text = _fromAirport.shortLabel;
      _toController.text = _toAirport.shortLabel;
      _fromMatches = const [];
      _toMatches = const [];
    });
    _runSearch(showErrors: false);
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _departDate,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGreen,
              secondary: AppColors.primaryGreen,
              surface: AppColors.cardBackground,
              error: AppColors.errorRed,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.darkBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null) return;
    setState(() => _departDate = selected);
  }

  void _runSearch({bool showErrors = true}) {
    final fromMatch = AirportDirectory.findBestMatch(
      _fromController.text,
      excludeCode: _toAirport.code,
    );
    final toMatch = AirportDirectory.findBestMatch(
      _toController.text,
      excludeCode: _fromAirport.code,
    );

    if (fromMatch == null ||
        toMatch == null ||
        fromMatch.code == toMatch.code) {
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose two different valid airports.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    final routeEntries = FlightCatalog.entries
        .where(
          (entry) =>
              entry.originCode == fromMatch.code &&
              entry.destinationCode == toMatch.code,
        )
        .toList();
    final entries = routeEntries.isNotEmpty
        ? routeEntries
        : FlightCatalog.entries
              .where(
                (entry) =>
                    entry.originCode == fromMatch.code ||
                    entry.destinationCode == toMatch.code,
              )
              .take(8)
              .toList();

    final results = entries
        .map(
          (entry) => _FlightSearchResult.fromCatalog(
            entry,
            cabinClass: _selectedCabin,
            passengers: _passengers,
            departDate: _departDate,
          ),
        )
        .toList();

    setState(() {
      _fromAirport = fromMatch;
      _toAirport = toMatch;
      _fromController.text = fromMatch.shortLabel;
      _toController.text = toMatch.shortLabel;
      _fromMatches = const [];
      _toMatches = const [];
      _results = results;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lowestCarbon = _lowestCarbonResult;
    final cheapest = _cheapestResult;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildSearchPanel(),
              const SizedBox(height: 18),
              if (lowestCarbon != null && cheapest != null)
                _buildRecommendationPair(lowestCarbon, cheapest)
              else
                _buildEmptyResultsCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  _FlightSearchResult? get _lowestCarbonResult {
    if (_results.isEmpty) return null;
    final sorted = [..._results]
      ..sort((a, b) => a.emissionsKg.compareTo(b.emissionsKg));
    return sorted.first;
  }

  _FlightSearchResult? get _cheapestResult {
    if (_results.isEmpty) return null;
    final sorted = [..._results]..sort((a, b) => a.price.compareTo(b.price));
    return sorted.first;
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flight Search',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Find the cleanest and cheapest options before you choose.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildChip(Icons.sync_alt, 'Round trip'),
              const SizedBox(width: 10),
              _buildChip(Icons.person_outline, '$_passengers'),
              const SizedBox(width: 10),
              Expanded(child: _buildCabinMenu()),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAirportInput(isFrom: true)),
                    const SizedBox(width: 12),
                    _buildSwapButton(),
                    const SizedBox(width: 12),
                    Expanded(child: _buildAirportInput(isFrom: false)),
                  ],
                );
              }

              return Column(
                children: [
                  _buildAirportInput(isFrom: true),
                  const SizedBox(height: 10),
                  _buildSwapButton(),
                  const SizedBox(height: 10),
                  _buildAirportInput(isFrom: false),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildDateField()),
              const SizedBox(width: 12),
              _buildPassengerStepper(),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _runSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.search),
              label: const Text(
                'Compare Flights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabinMenu() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<CabinClass>(
        value: _selectedCabin,
        dropdownColor: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        isExpanded: true,
        iconEnabledColor: AppColors.textSecondary,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        items: CabinClass.values.map((cabin) {
          return DropdownMenuItem(value: cabin, child: Text(cabin.displayName));
        }).toList(),
        onChanged: (cabin) {
          if (cabin == null) return;
          setState(() => _selectedCabin = cabin);
          _runSearch(showErrors: false);
        },
      ),
    );
  }

  Widget _buildAirportInput({required bool isFrom}) {
    final controller = isFrom ? _fromController : _toController;
    final focusNode = isFrom ? _fromFocusNode : _toFocusNode;
    final matches = isFrom ? _fromMatches : _toMatches;

    return Column(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) => _updateAirportMatches(value, isFrom: isFrom),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: isFrom ? 'From' : 'To',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(
              isFrom ? Icons.trip_origin : Icons.location_on_outlined,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF586A7C)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF586A7C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen),
            ),
          ),
        ),
        if (focusNode.hasFocus && matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF586A7C)),
            ),
            child: Column(
              children: matches.take(5).map((airport) {
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.flight,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(
                    airport.shortLabel,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    airport.name,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => _selectAirport(airport, isFrom: isFrom),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSwapButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton.filled(
        onPressed: _swapAirports,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: Color(0xFF586A7C)),
        ),
        icon: const Icon(Icons.swap_horiz),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF586A7C)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatDate(_departDate),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerStepper() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF586A7C)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _passengers > 1
                ? () {
                    setState(() => _passengers -= 1);
                    _runSearch(showErrors: false);
                  }
                : null,
            icon: const Icon(Icons.remove),
            color: AppColors.textPrimary,
          ),
          Text(
            '$_passengers',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _passengers += 1);
              _runSearch(showErrors: false);
            },
            icon: const Icon(Icons.add),
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationPair(
    _FlightSearchResult lowestCarbon,
    _FlightSearchResult cheapest,
  ) {
    final sameFlight = lowestCarbon.entry.id == cheapest.entry.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Best Matches',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${_results.length} checked',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildResultCard(
          title: sameFlight ? 'Best Overall' : 'Lowest CO\u2082',
          result: lowestCarbon,
          accent: AppColors.primaryGreen,
          icon: Icons.eco_outlined,
        ),
        if (!sameFlight) ...[
          const SizedBox(height: 12),
          _buildResultCard(
            title: 'Cheapest',
            result: cheapest,
            accent: AppColors.warningOrange,
            icon: Icons.payments_outlined,
          ),
        ],
      ],
    );
  }

  Widget _buildResultCard({
    required String title,
    required _FlightSearchResult result,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${result.entry.airlineName} ${result.entry.compactFlightCode}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${result.price}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.entry.routeCodeLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.entry.routeCityLabel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'CO\u2082',
                  '${result.emissionsKg.round()} kg',
                  AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  'Distance',
                  '${result.distanceMiles.round()} mi',
                  const Color(0xFF82A8FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  'Cabin',
                  _selectedCabin.displayName,
                  AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          Icon(
            _hasSearched ? Icons.search_off : Icons.travel_explore,
            color: AppColors.textSecondary,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _hasSearched
                ? 'No catalog flights found for this search.'
                : 'Search to compare cleaner and cheaper flights.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try JFK to LAX, SFO to SEA, or LAX to NRT.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _FlightSearchResult {
  final FlightCatalogEntry entry;
  final double emissionsKg;
  final int price;
  final double distanceMiles;

  _FlightSearchResult({
    required this.entry,
    required this.emissionsKg,
    required this.price,
    required this.distanceMiles,
  });

  factory _FlightSearchResult.fromCatalog(
    FlightCatalogEntry entry, {
    required CabinClass cabinClass,
    required int passengers,
    required DateTime departDate,
  }) {
    final origin = AirportDirectory.airports.firstWhere(
      (airport) => airport.code == entry.originCode,
    );
    final destination = AirportDirectory.airports.firstWhere(
      (airport) => airport.code == entry.destinationCode,
    );
    final distanceMiles = _distanceMiles(origin, destination);
    final emissionsKg =
        distanceMiles *
        _emissionsRateFor(entry.carrierCode) *
        _cabinEmissionMultiplier(cabinClass) *
        passengers;
    final price =
        (distanceMiles * _priceRateFor(entry.carrierCode) * passengers)
            .round() +
        _cabinPricePremium(cabinClass) +
        _dateDemandPremium(departDate);

    return _FlightSearchResult(
      entry: entry,
      emissionsKg: emissionsKg,
      price: max(price, 79),
      distanceMiles: distanceMiles,
    );
  }

  static double _distanceMiles(
    AirportOption origin,
    AirportOption destination,
  ) {
    const earthRadiusMiles = 3958.8;
    final lat1 = _toRadians(origin.latitude);
    final lat2 = _toRadians(destination.latitude);
    final deltaLat = _toRadians(destination.latitude - origin.latitude);
    final deltaLon = _toRadians(destination.longitude - origin.longitude);
    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  static double _emissionsRateFor(String carrierCode) {
    return switch (carrierCode) {
      'B6' || 'AS' || 'WN' => 0.135,
      'DL' || 'UA' => 0.148,
      'AA' => 0.156,
      'NH' || 'SQ' => 0.162,
      _ => 0.172,
    };
  }

  static double _priceRateFor(String carrierCode) {
    return switch (carrierCode) {
      'WN' || 'AS' => 0.115,
      'B6' => 0.13,
      'AA' => 0.142,
      'DL' => 0.151,
      'UA' => 0.158,
      _ => 0.18,
    };
  }

  static double _cabinEmissionMultiplier(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 1,
      CabinClass.premiumEconomy => 1.6,
      CabinClass.business => 2.8,
      CabinClass.first => 4,
    };
  }

  static int _cabinPricePremium(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 0,
      CabinClass.premiumEconomy => 180,
      CabinClass.business => 780,
      CabinClass.first => 1450,
    };
  }

  static int _dateDemandPremium(DateTime date) {
    return switch (date.weekday) {
      DateTime.friday || DateTime.sunday => 46,
      DateTime.saturday => 28,
      _ => 12,
    };
  }
}
