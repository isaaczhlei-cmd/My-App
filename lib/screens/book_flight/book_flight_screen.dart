import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/booking_link_service.dart';
import '../../services/booking_provider_service.dart';
import '../../services/emissions_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/airport_autocomplete_field.dart';
import '../add_flight/flight_catalog.dart';
import '../profile/guest_sign_in_prompt_screen.dart';
import 'airport_directory.dart';
import 'booking_handoff_screen.dart';

class BookFlightScreen extends StatefulWidget {
  const BookFlightScreen({super.key});

  @override
  State<BookFlightScreen> createState() => _BookFlightScreenState();
}

class _BookFlightScreenState extends State<BookFlightScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  bool _isRoundTrip = true;
  BookingProvider _selectedProvider = BookingProvider.automatic;
  AirportOption _fromAirport = AirportDirectory.airports.firstWhere(
    (airport) => airport.code == 'JFK',
  );
  AirportOption _toAirport = AirportDirectory.airports.firstWhere(
    (airport) => airport.code == 'LAX',
  );
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final TextEditingController _airlineController;
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();
  List<AirportOption> _fromMatches = const [];
  List<AirportOption> _toMatches = const [];
  late final AnimationController _swapAnimationController;
  late final Animation<double> _swapRotationAnimation;
  late DateTime _departDate;
  late DateTime _returnDate;
  late bool _departSelected;
  late bool _returnSelected;
  int _passengers = 1;
  CabinClass _selectedCabin = CabinClass.economy;
  String? _selectedAirlineFilter;
  List<_FlightSearchResult> _results = const [];
  bool _hasSearchedCatalog = false;
  String? _emptyResultsMessage;

  @override
  void initState() {
    super.initState();
    _swapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _swapRotationAnimation = CurvedAnimation(
      parent: _swapAnimationController,
      curve: Curves.easeInOut,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    // Default depart date two weeks from today (e.g., Jun 15)
    _departDate = today.add(const Duration(days: 14));
    _returnDate = _departDate.add(const Duration(days: 2));
    // Start inputs blank; user will type the airports
    _fromController = TextEditingController();
    _toController = TextEditingController();
    _airlineController = TextEditingController();
    _departSelected = false;
    _returnSelected = false;

    _fromFocusNode.addListener(_handleFocusChange);
    _toFocusNode.addListener(_handleFocusChange);

    // Load saved booking provider preference
    _loadSavedProvider();
    _refreshCatalogResults();
  }

  Future<void> _loadSavedProvider() async {
    final savedProvider = await BookingProviderService.getSelectedProvider();
    if (mounted) {
      setState(() {
        _selectedProvider = savedProvider;
      });
    }
  }

  @override
  void dispose() {
    _swapAnimationController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _airlineController.dispose();
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
      setState(() {
        _fromMatches = const [];
      });
    }
    if (!_toFocusNode.hasFocus && _toMatches.isNotEmpty) {
      setState(() {
        _toMatches = const [];
      });
    }
  }

  Future<void> _selectDate({required bool isReturn}) async {
    FocusScope.of(context).unfocus();

    final initialDate = isReturn ? _returnDate : _departDate;
    final firstDate = isReturn ? _departDate : DateTime(2025);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2030),
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: scheme.copyWith(
              primary: scheme.primary,
              secondary: scheme.secondary,
              surface: scheme.surface,
              error: AppColors.errorRed,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (isReturn) {
        _returnDate = selected;
        _returnSelected = true;
      } else {
        _departDate = selected;
        _departSelected = true;
        if (_returnDate.isBefore(_departDate)) {
          _returnDate = _departDate.add(const Duration(days: 7));
        }
      }
    });
    _refreshCatalogResults();
  }

  void _updateAirportMatches(String query, {required bool isFrom}) {
    // Only exclude the opposite airport when that input has a value
    // (so default internal values like LAX don't hide matching results).
    final otherController = isFrom ? _toController : _fromController;
    final exclude = otherController.text.trim().isEmpty
        ? null
        : (isFrom ? _toAirport.code : _fromAirport.code);
    final matches = AirportDirectory.search(query, excludeCode: exclude);
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
    _refreshCatalogResults();
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
    _swapAnimationController.forward(from: 0);
    _refreshCatalogResults();
  }

  Future<void> _runSearch() async {
    if (_isGuest) {
      _openGuestPrompt();
      return;
    }

    final fromMatch = AirportDirectory.findBestMatch(
      _fromController.text,
      excludeCode: _toAirport.code,
    );
    final toMatch = AirportDirectory.findBestMatch(
      _toController.text,
      excludeCode: _fromAirport.code,
    );

    if (fromMatch == null || toMatch == null) {
      // If one or both fields didn't match, try to suggest a close code
      // (helpful for small typos like SZH -> SZX). If we find a suggestion
      // present it as an action the user can accept.
      final fromSuggestion = fromMatch == null
          ? AirportDirectory.findClosestCode(
              _fromController.text,
              excludeCode: _toAirport.code,
            )
          : null;
      final toSuggestion = toMatch == null
          ? AirportDirectory.findClosestCode(
              _toController.text,
              excludeCode: _fromAirport.code,
            )
          : null;

      if (fromSuggestion != null || toSuggestion != null) {
        final suggestion = fromSuggestion ?? toSuggestion!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No exact airport match. Did you mean ${suggestion.code} (${suggestion.city})?',
            ),
            action: SnackBarAction(
              label: 'Use ${suggestion.code}',
              onPressed: () {
                setState(() {
                  if (fromSuggestion != null) {
                    _fromController.text = fromSuggestion.shortLabel;
                  }
                  if (toSuggestion != null) {
                    _toController.text = toSuggestion.shortLabel;
                  }
                });
                // Try the search again with the suggested values.
                _runSearch();
              },
            ),
            backgroundColor: AppColors.warningOrange,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose valid departure and arrival airports.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (fromMatch.code == toMatch.code) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departure and arrival airports need to be different.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _fromAirport = fromMatch;
      _toAirport = toMatch;
      _fromController.text = fromMatch.shortLabel;
      _toController.text = toMatch.shortLabel;
      _fromMatches = const [];
      _toMatches = const [];
    });
    _refreshCatalogResults();

    final outboundUrl = _buildSearchUri(
      origin: fromMatch.code,
      destination: toMatch.code,
      departureDate: _departDate,
    );

    if (!_isRoundTrip) {
      await _launchExternalSearch(outboundUrl);
      return;
    }

    final returnUrl = _buildSearchUri(
      origin: toMatch.code,
      destination: fromMatch.code,
      departureDate: _returnDate,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingHandoffScreen(
          origin: fromMatch.shortLabel,
          destination: toMatch.shortLabel,
          outboundDate: _departDate,
          returnDate: _returnDate,
          outboundUrl: outboundUrl,
          returnUrl: returnUrl,
          onLaunchUrl: _launchExternalSearch,
        ),
      ),
    );
  }

  void _openGuestPrompt() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const GuestSignInPromptScreen(featureLabel: 'flight booking'),
      ),
    );
  }

  void _refreshCatalogResults() {
    // Fall back to the selected airports when the text inputs are blank so the
    // default route (e.g. JFK -> LAX) shows results immediately, mirroring how
    // _maxPassengersForCurrentSearch resolves the route.
    final fromMatch =
        AirportDirectory.findBestMatch(
          _fromController.text,
          excludeCode: _toAirport.code,
        ) ??
        _fromAirport;
    final toMatch =
        AirportDirectory.findBestMatch(
          _toController.text,
          excludeCode: _fromAirport.code,
        ) ??
        _toAirport;

    if (fromMatch.code == toMatch.code) {
      setState(() {
        _results = const [];
        _hasSearchedCatalog = true;
        _emptyResultsMessage = 'Choose two different valid airports.';
      });
      return;
    }

    final entries = _entriesForRoute(fromMatch, toMatch);
    final maxPassengers = _maxPassengersForEntries(entries);
    final passengers = maxPassengers == 0 ? 1 : min(_passengers, maxPassengers);
    final results = entries
        .where((entry) {
          final capacity = entry.capacityFor(_selectedCabin);
          return capacity > 0 && passengers <= capacity;
        })
        .map(
          (entry) => _FlightSearchResult.fromCatalog(
            entry,
            cabinClass: _selectedCabin,
            passengers: passengers,
            departDate: _departDate,
          ),
        )
        .toList();

    setState(() {
      _passengers = passengers;
      _results = results;
      _hasSearchedCatalog = true;
      _emptyResultsMessage = entries.isNotEmpty && results.isEmpty
          ? 'No flights can carry this group in ${_selectedCabin.displayName}.'
          : null;
    });
  }

  List<FlightCatalogEntry> _entriesForRoute(
    AirportOption fromAirport,
    AirportOption toAirport,
  ) {
    final routeEntries = FlightCatalog.entries
        .where(
          (entry) =>
              entry.originCode == fromAirport.code &&
              entry.destinationCode == toAirport.code,
        )
        .toList();
    if (routeEntries.isNotEmpty) return _filterEntriesByAirline(routeEntries);

    final fallbackEntries = FlightCatalog.entries
        .where(
          (entry) =>
              entry.originCode == fromAirport.code ||
              entry.destinationCode == toAirport.code,
        )
        .take(8)
        .toList();
    return _filterEntriesByAirline(fallbackEntries);
  }

  List<FlightCatalogEntry> _filterEntriesByAirline(
    List<FlightCatalogEntry> entries,
  ) {
    final airline = _resolvedAirlineFilter;
    if (airline == null) return entries;
    return entries.where((entry) => entry.airlineName == airline).toList();
  }

  String? get _resolvedAirlineFilter {
    if (_selectedAirlineFilter != null) return _selectedAirlineFilter;
    final query = _airlineController.text.trim().toLowerCase();
    if (query.isEmpty) return null;

    final options = FlightCatalog.airlineOptions();
    for (final airline in options) {
      if (airline.toLowerCase() == query) return airline;
    }
    final matches = options
        .where((airline) => airline.toLowerCase().contains(query))
        .toList();
    return matches.length == 1 ? matches.first : null;
  }

  List<String> get _visibleAirlineMatches {
    final query = _airlineController.text.trim().toLowerCase();
    final options = FlightCatalog.airlineOptions();
    if (query.isEmpty) return options.take(8).toList();
    return options
        .where((airline) => airline.toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  int get _maxPassengersForCurrentSearch {
    final fromMatch =
        AirportDirectory.findBestMatch(
          _fromController.text,
          excludeCode: _toAirport.code,
        ) ??
        _fromAirport;
    final toMatch =
        AirportDirectory.findBestMatch(
          _toController.text,
          excludeCode: _fromAirport.code,
        ) ??
        _toAirport;

    if (fromMatch.code == toMatch.code) return 1;
    return _maxPassengersForEntries(_entriesForRoute(fromMatch, toMatch));
  }

  int _maxPassengersForEntries(List<FlightCatalogEntry> entries) {
    var maxPassengers = 0;
    for (final entry in entries) {
      maxPassengers = max(maxPassengers, entry.capacityFor(_selectedCabin));
    }
    return maxPassengers;
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

  bool get _isGuest {
    try {
      return _authService.isGuest;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (_isGuest) ...[
                _buildGuestAccessCard(),
                const SizedBox(height: 20),
              ],
              _buildBookingCard(),
              const SizedBox(height: 20),
              _buildFlightResultsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3954D9), Color(0xFF4C43E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book a Flight',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Compare price and carbon before you book',
            style: TextStyle(fontSize: 16, color: Color(0xFFDCE2FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestAccessCard() {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warningOrange.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.warningOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sign in required',
                  style: TextStyle(
                    color: themeColors.onCard,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Guests can explore the form, but you need to sign in before opening live flight results.',
            style: TextStyle(
              color: themeColors.onCardMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTripToggle(),
          const SizedBox(height: 18),
          _buildFieldLabel(Icons.flight_takeoff, 'From'),
          const SizedBox(height: 8),
          _buildAirportInput(
            controller: _fromController,
            focusNode: _fromFocusNode,
            hintText: 'Type in the airport',
            matches: _fromMatches,
            onChanged: (value) => _updateAirportMatches(value, isFrom: true),
            onSelected: (airport) => _selectAirport(airport, isFrom: true),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: themeColors.cardMuted,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: themeColors.outlineSoft),
              ),
              child: IconButton(
                onPressed: _swapAirports,
                icon: RotationTransition(
                  turns: _swapRotationAnimation,
                  child: Icon(
                    Icons.swap_vert,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          _buildFieldLabel(Icons.flight_land, 'To'),
          const SizedBox(height: 8),
          _buildAirportInput(
            controller: _toController,
            focusNode: _toFocusNode,
            hintText: 'Type in the airport',
            matches: _toMatches,
            onChanged: (value) => _updateAirportMatches(value, isFrom: false),
            onSelected: (airport) => _selectAirport(airport, isFrom: false),
          ),
          const SizedBox(height: 18),
          _buildFieldLabel(Icons.airlines, 'Airline'),
          const SizedBox(height: 8),
          _buildAirlineInput(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Depart',
                  date: _departDate,
                  onTap: () => _selectDate(isReturn: false),
                  selected: _departSelected,
                ),
              ),
              if (_isRoundTrip) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Return',
                    date: _returnDate,
                    onTap: () => _selectDate(isReturn: true),
                    selected: _returnSelected,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _buildFieldLabel(Icons.people_outline, 'Passengers'),
          const SizedBox(height: 8),
          _buildPassengerField(),
          const SizedBox(height: 18),
          _buildFieldLabel(Icons.airline_seat_recline_normal, 'Cabin Class'),
          const SizedBox(height: 8),
          _buildCabinClassSelector(),
          const SizedBox(height: 18),
          _buildFieldLabel(Icons.card_travel, 'Booking Provider'),
          const SizedBox(height: 8),
          _buildProviderSelector(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _runSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Search Flights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripToggle() {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isRoundTrip = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _isRoundTrip ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Round Trip',
                    style: TextStyle(
                      color: _isRoundTrip
                          ? Colors.white
                          : themeColors.onCardMuted,
                      fontWeight: _isRoundTrip
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isRoundTrip = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !_isRoundTrip ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'One Way',
                    style: TextStyle(
                      color: !_isRoundTrip
                          ? Colors.white
                          : themeColors.onCardMuted,
                      fontWeight: !_isRoundTrip
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(IconData icon, String label) {
    final themeColors = context.appColors;

    return Row(
      children: [
        Icon(icon, size: 18, color: themeColors.onCardMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: themeColors.onCard,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAirportInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required List<AirportOption> matches,
    required ValueChanged<String> onChanged,
    required ValueChanged<AirportOption> onSelected,
  }) {
    final themeColors = context.appColors;

    return AirportAutocompleteField(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      matches: matches,
      onChanged: onChanged,
      onSelected: onSelected,
      prefixIcon: Icons.search,
      fillColor: themeColors.cardMuted,
      borderColor: themeColors.outlineSoft,
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(color: themeColors.onCardMuted),
    );
  }

  Widget _buildAirlineInput() {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;
    final matches = _visibleAirlineMatches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _airlineController,
          cursorColor: accent,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            color: accent,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Type airline name',
            hintStyle: TextStyle(color: themeColors.onCardMuted),
            filled: true,
            fillColor: themeColors.cardMuted,
            prefixIcon: Icon(Icons.search, color: themeColors.onCardMuted),
            suffixIcon: _airlineController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      setState(() {
                        _airlineController.clear();
                        _selectedAirlineFilter = null;
                      });
                      _refreshCatalogResults();
                    },
                    icon: Icon(Icons.close, color: themeColors.onCardMuted),
                  ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeColors.outlineSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeColors.outlineSoft),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _selectedAirlineFilter = null;
            });
            _refreshCatalogResults();
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final airline = matches[index];
              final selected = _resolvedAirlineFilter == airline;
              return ChoiceChip(
                label: Text(airline),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedAirlineFilter = airline;
                    _airlineController.text = airline;
                  });
                  _refreshCatalogResults();
                },
                labelStyle: TextStyle(
                  color: selected ? Colors.white : themeColors.onCardMuted,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: themeColors.cardMuted,
                selectedColor: accent,
                side: BorderSide(
                  color: selected ? accent : themeColors.outlineSoft,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required bool selected,
  }) {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(Icons.calendar_today_outlined, label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: themeColors.cardMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeColors.outlineSoft),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected ? _formatDate(date) : 'Select',
                    style: TextStyle(
                      color: selected ? accent : themeColors.onCardMuted,
                      fontSize: selected ? 15 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: themeColors.onCardMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerField() {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;
    final maxPassengers = _maxPassengersForCurrentSearch;
    final canAdd = maxPassengers == 0 || _passengers < maxPassengers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('decrement-passengers'),
                onPressed: _passengers > 1
                    ? () {
                        setState(() {
                          _passengers -= 1;
                        });
                        _refreshCatalogResults();
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: accent,
              ),
              Expanded(
                child: Text(
                  '$_passengers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('increment-passengers'),
                onPressed: canAdd
                    ? () {
                        setState(() {
                          _passengers = maxPassengers == 0
                              ? _passengers + 1
                              : min(_passengers + 1, maxPassengers);
                        });
                        _refreshCatalogResults();
                      }
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: accent,
              ),
            ],
          ),
          if (maxPassengers > 0 && _passengers >= maxPassengers) ...[
            const SizedBox(height: 4),
            Text(
              'Max $maxPassengers for ${_selectedCabin.displayName}',
              style: TextStyle(
                color: themeColors.onCardMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCabinClassSelector() {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CabinClass.values.map((cabin) {
        final isSelected = cabin == _selectedCabin;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCabin = cabin;
            });
            _refreshCatalogResults();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? accent : themeColors.cardMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? accent : themeColors.outlineSoft,
              ),
            ),
            child: Text(
              cabin.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : themeColors.onCardMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProviderSelector() {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: BookingProvider.values.map((provider) {
        final isSelected = provider == _selectedProvider;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedProvider = provider;
            });
            // Save the selected provider preference
            BookingProviderService.setSelectedProvider(provider);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? accent : themeColors.cardMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? accent : themeColors.outlineSoft,
              ),
            ),
            child: Text(
              provider.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : themeColors.onCardMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlightResultsSection() {
    final lowestCarbon = _lowestCarbonResult;
    final cheapest = _cheapestResult;

    if (lowestCarbon == null || cheapest == null) {
      return _buildEmptyResultsCard();
    }

    final themeColors = context.appColors;
    final sameFlight = lowestCarbon.entry.id == cheapest.entry.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Best Matches',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${_results.length} checked',
              style: TextStyle(color: themeColors.onCardMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildResultCard(
          title: sameFlight ? 'Best Overall' : 'Lowest CO₂',
          result: lowestCarbon,
          accent: Theme.of(context).colorScheme.primary,
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
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(20),
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
                      style: TextStyle(
                        color: themeColors.onCard,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${result.price}',
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.entry.routeCodeLabel,
            style: TextStyle(
              color: themeColors.onCard,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.entry.routeCityLabel,
            style: TextStyle(color: themeColors.onCardMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'CO₂',
                  '${result.emissionsKg.round()} kg',
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  'Distance',
                  '${result.distanceMiles.round()} mi',
                  const Color(0xFF3954D9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  'Cabin',
                  _selectedCabin.displayName,
                  themeColors.onCardMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    final themeColors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColors.outlineSoft),
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
            style: TextStyle(
              color: themeColors.onCard,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsCard() {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        children: [
          Icon(
            _hasSearchedCatalog ? Icons.search_off : Icons.travel_explore,
            color: themeColors.onCardMuted,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _hasSearchedCatalog
                ? _emptyResultsMessage ??
                      'No catalog flights found for this search.'
                : 'Search to compare cleaner and cheaper flights.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: themeColors.onCard,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try JFK to LAX, SFO to SEA, or LAX to NRT.',
            textAlign: TextAlign.center,
            style: TextStyle(color: themeColors.onCardMuted),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Uri _buildSearchUri({
    required String origin,
    required String destination,
    required DateTime departureDate,
  }) {
    return switch (_selectedProvider) {
      BookingProvider.automatic ||
      BookingProvider.googleFlights => BookingLinkService.googleFlightsUri(
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        passengers: _passengers,
        cabinClass: _selectedCabin,
      ),
      BookingProvider.kayak => BookingLinkService.kayakUri(
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        passengers: _passengers,
        cabinClass: _selectedCabin,
      ),
      BookingProvider.skyscanner => BookingLinkService.skyscannerUri(
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        passengers: _passengers,
        cabinClass: _selectedCabin,
      ),
    };
  }

  Future<bool> _launchExternalSearch(Uri url) async {
    var success = await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!success) {
      success = await launchUrl(url, mode: LaunchMode.platformDefault);
    }

    if (!success) {
      success = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the flight search site.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }

    return success;
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
