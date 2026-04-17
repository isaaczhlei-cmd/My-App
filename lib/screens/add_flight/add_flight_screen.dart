import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/auth_service.dart';
import '../../services/emissions_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_bottom_nav.dart';
import 'flight_catalog.dart';

class AddFlightScreen extends StatefulWidget {
  const AddFlightScreen({super.key});

  @override
  State<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends State<AddFlightScreen> {
  static const _hiddenCatalogPrefsKey = 'debug_hidden_flight_catalog_entries';

  final _heroSearchController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _emissionsService = EmissionsService();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  DateTime _selectedDate = DateTime.now();
  bool _hasResult = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _manualEntryExpanded = false;
  bool _didLoadDebugHiddenEntries = !kDebugMode;
  String? _errorMessage;
  String? _selectedAirlineFilter;
  FlightCatalogEntry? _selectedCatalogEntry;
  Set<String> _hiddenCatalogEntryIds = <String>{};
  final Map<String, _CatalogVerificationStatus> _verificationStatusByKey = {};
  final Set<String> _activeVerificationKeys = <String>{};

  String _origin = '';
  String _destination = '';
  String _airlineCode = '';
  int _flightNum = 0;
  double _emissionsKg = 0;
  CabinClass _selectedCabin = CabinClass.economy;

  FlightEmission? _flightEmission;
  TypicalRouteEmission? _typicalEmission;
  bool _usedTypicalFallback = false;

  @override
  void initState() {
    super.initState();
    _loadHiddenCatalogEntries();
  }

  @override
  void dispose() {
    _heroSearchController.dispose();
    _flightNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  ({String carrier, int number})? _parseFlightNumber(String input) {
    final cleaned = input.trim().toUpperCase();
    final regex = RegExp(r'^([A-Z]{2})\s*[-]?\s*(\d{1,5})$');
    final match = regex.firstMatch(cleaned);
    if (match == null) return null;
    final carrier = match.group(1)!;
    final number = int.tryParse(match.group(2)!);
    if (number == null) return null;
    return (carrier: carrier, number: number);
  }

  String? _parseAirportCode(String input) {
    final cleaned = input.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z]{3}$');
    if (!regex.hasMatch(cleaned)) return null;
    return cleaned;
  }

  void _clearLookupResult() {
    _hasResult = false;
    _flightEmission = null;
    _typicalEmission = null;
    _usedTypicalFallback = false;
    _origin = '';
    _destination = '';
    _airlineCode = '';
    _flightNum = 0;
    _emissionsKg = 0;
  }

  List<String> get _airlineFilters => FlightCatalog.airlineOptions();

  List<FlightCatalogEntry> get _suggestedFlights {
    final query = _heroSearchController.text.trim();
    if (query.isEmpty) return const [];
    final matches = FlightCatalog.search(
      query,
      airlineName: _selectedAirlineFilter,
      limit: 6,
      hiddenEntryIds: _hiddenCatalogEntryIds,
    );
    return _filterVerifiedEntries(matches);
  }

  List<FlightCatalogEntry> get _catalogFlights {
    final query = _heroSearchController.text.trim();
    if (query.isEmpty) {
      return FlightCatalog.featured(
        airlineName: _selectedAirlineFilter,
        limit: 12,
        hiddenEntryIds: _hiddenCatalogEntryIds,
      );
    }
    final matches = FlightCatalog.search(
      query,
      airlineName: _selectedAirlineFilter,
      limit: 16,
      hiddenEntryIds: _hiddenCatalogEntryIds,
    );
    return _filterVerifiedEntries(matches);
  }

  List<FlightCatalogEntry> _filterVerifiedEntries(List<FlightCatalogEntry> entries) {
    if (kDebugMode) return entries;
    return entries.where((entry) {
      return _verificationStatusFor(entry) != _CatalogVerificationStatus.invalid;
    }).toList();
  }

  Future<void> _lookupFlight() async {
    final parsed = _parseFlightNumber(_flightNumberController.text);
    if (parsed == null) {
      setState(() {
        _errorMessage = 'Enter a valid flight number (e.g. UA 857)';
        _clearLookupResult();
      });
      return;
    }

    final origin = _parseAirportCode(_originController.text);
    final destination = _parseAirportCode(_destinationController.text);
    if (origin == null || destination == null) {
      setState(() {
        _errorMessage = 'Enter valid 3-letter airport codes like SFO and JFK';
        _clearLookupResult();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _clearLookupResult();
    });

    final result = await _emissionsService.computeFlightEmissions(
      origin: origin,
      destination: destination,
      operatingCarrierCode: parsed.carrier,
      flightNumber: parsed.number,
      departureDate: _selectedDate,
    );

    if (!mounted) return;

    if (result != null && result.flightEmissions.isNotEmpty) {
      final emission = result.flightEmissions.first;
      final kg = emission.getEmissionsKg(_selectedCabin);

      if (kg > 0) {
        setState(() {
          _flightEmission = emission;
          _origin = emission.flight?.origin ?? origin;
          _destination = emission.flight?.destination ?? destination;
          _airlineCode = emission.flight?.operatingCarrierCode ?? parsed.carrier;
          _flightNum = emission.flight?.flightNumber ?? parsed.number;
          _emissionsKg = kg;
          _usedTypicalFallback = false;
          _isLoading = false;
          _hasResult = true;
        });
        return;
      }
    }

    final typicalResult = await _emissionsService.computeTypicalEmissions(
      origin: origin,
      destination: destination,
    );

    if (!mounted) return;

    if (typicalResult != null && typicalResult.typicalEmissions.isNotEmpty) {
      final typical = typicalResult.typicalEmissions.first;
      final kg = typical.getEmissionsKg(_selectedCabin);

      setState(() {
        _typicalEmission = typical;
        _origin = origin;
        _destination = destination;
        _airlineCode = parsed.carrier;
        _flightNum = parsed.number;
        _emissionsKg = kg;
        _usedTypicalFallback = true;
        _isLoading = false;
        _hasResult = true;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not find emissions data for this route. Double-check the airport codes.';
      });
    }
  }

  void _onCabinChanged(CabinClass cabin) {
    setState(() {
      _selectedCabin = cabin;
      if (_flightEmission != null) {
        _emissionsKg = _flightEmission!.getEmissionsKg(cabin);
      } else if (_typicalEmission != null) {
        _emissionsKg = _typicalEmission!.getEmissionsKg(cabin);
      }
    });
  }

  void _onHeroQueryChanged(String value) {
    setState(() {
      _errorMessage = null;
      if (_selectedCatalogEntry != null &&
          value.trim().toLowerCase() !=
              _selectedCatalogEntry!.flightCode.toLowerCase()) {
        _selectedCatalogEntry = null;
        _clearLookupResult();
      }
    });
    _verifyVisibleCatalogEntries();
  }

  Future<void> _selectCatalogFlight(FlightCatalogEntry entry) async {
    setState(() {
      _selectedCatalogEntry = entry;
      _heroSearchController.text = entry.flightCode;
      _flightNumberController.text = entry.flightCode;
      _originController.text = entry.originCode;
      _destinationController.text = entry.destinationCode;
      _errorMessage = null;
      _clearLookupResult();
    });

    await _lookupFlight();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGreen,
              surface: AppColors.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _errorMessage = null;
        _clearLookupResult();
      });
      _verifyVisibleCatalogEntries(forceRefresh: true);
    }
  }

  Future<void> _loadHiddenCatalogEntries() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    final hiddenIds =
        prefs.getStringList(_hiddenCatalogPrefsKey)?.toSet() ?? <String>{};
    if (!mounted) return;
    setState(() {
      _hiddenCatalogEntryIds = hiddenIds;
      _didLoadDebugHiddenEntries = true;
    });
    _verifyVisibleCatalogEntries();
  }

  Future<void> _hideCatalogEntry(FlightCatalogEntry entry) async {
    if (!kDebugMode) return;
    final nextHidden = {..._hiddenCatalogEntryIds, entry.id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenCatalogPrefsKey, nextHidden.toList()..sort());
    if (!mounted) return;
    setState(() {
      _hiddenCatalogEntryIds = nextHidden;
      if (_selectedCatalogEntry?.id == entry.id) {
        _selectedCatalogEntry = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.flightCode} hidden for this debug build.'),
        backgroundColor: AppColors.warningOrange,
      ),
    );
  }

  void _verifyVisibleCatalogEntries({bool forceRefresh = false}) {
    final query = _heroSearchController.text.trim();
    if (query.isEmpty) return;

    final visibleEntries = <FlightCatalogEntry>[
      ...FlightCatalog.search(
        query,
        airlineName: _selectedAirlineFilter,
        limit: 6,
        hiddenEntryIds: _hiddenCatalogEntryIds,
      ),
      ...FlightCatalog.search(
        query,
        airlineName: _selectedAirlineFilter,
        limit: 16,
        hiddenEntryIds: _hiddenCatalogEntryIds,
      ),
    ];

    final seenIds = <String>{};
    for (final entry in visibleEntries) {
      if (!seenIds.add(entry.id)) continue;
      final key = _verificationKeyFor(entry);
      if (!forceRefresh &&
          (_verificationStatusByKey.containsKey(key) || _activeVerificationKeys.contains(key))) {
        continue;
      }
      _startVerification(entry);
    }
  }

  Future<void> _startVerification(FlightCatalogEntry entry) async {
    final key = _verificationKeyFor(entry);
    setState(() {
      _activeVerificationKeys.add(key);
      _verificationStatusByKey[key] = _CatalogVerificationStatus.verifying;
    });

    final result = await _emissionsService.computeFlightEmissions(
      origin: entry.originCode,
      destination: entry.destinationCode,
      operatingCarrierCode: entry.carrierCode,
      flightNumber: entry.flightNumber,
      departureDate: _selectedDate,
    );

    if (!mounted) return;

    final isValid = result != null && result.flightEmissions.isNotEmpty;
    setState(() {
      _activeVerificationKeys.remove(key);
      _verificationStatusByKey[key] =
          isValid ? _CatalogVerificationStatus.valid : _CatalogVerificationStatus.invalid;
    });
  }

  String _verificationKeyFor(FlightCatalogEntry entry) {
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    return '${entry.id}_${_selectedDate.year}-$month-$day';
  }

  _CatalogVerificationStatus _verificationStatusFor(FlightCatalogEntry entry) {
    return _verificationStatusByKey[_verificationKeyFor(entry)] ??
        _CatalogVerificationStatus.unverified;
  }

  Future<void> _addToFlightLog() async {
    if (_authService.isGuest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to save flights to your log'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final flight = Flight(
      id: '',
      originCode: _origin,
      destinationCode: _destination,
      date: _selectedDate,
      travelClass: _selectedCabin.displayName,
      emissionsKg: _emissionsKg,
      createdAt: DateTime.now(),
      AirlineCode: _airlineCode,
      AirlineNumber: _flightNum.toString(),
    );

    await _firestoreService.addFlight(flight);

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flight added to your log!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );

    setState(() {
      _clearLookupResult();
      _selectedCatalogEntry = null;
      _heroSearchController.clear();
      _flightNumberController.clear();
      _originController.clear();
      _destinationController.clear();
      _flightEmission = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildHeroSearchCard(),
              const SizedBox(height: 18),
              _buildTripSettingsCard(),
              const SizedBox(height: 18),
              _buildFlightCatalogCard(),
              const SizedBox(height: 18),
              _buildManualEntryCard(),
              const SizedBox(height: 24),
              if (_errorMessage != null) _buildErrorMessage(),
              if (_isLoading) _buildLoadingIndicator(),
              if (_hasResult && !_isLoading) ...[
                _buildRouteCard(),
                const SizedBox(height: 16),
                _buildFlightDetails(),
                const SizedBox(height: 20),
                _buildEmissionsCard(),
                const SizedBox(height: 24),
                _buildAddButton(),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Flight',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Search, browse, and add a flight with one tap.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSearchCard() {
    final suggestions = _suggestedFlights;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF24415B), Color(0xFF1B2838)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your flight fast',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type a flight number, airline, or route and the app will suggest flights you can add instantly.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFFD6E0E7),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _heroSearchController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Try UA 857, Delta, or SFO to JFK',
                hintStyle: const TextStyle(color: Color(0xFF93A1AE)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF607080)),
                suffixIcon: _heroSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _heroSearchController.clear();
                            _selectedCatalogEntry = null;
                            _errorMessage = null;
                            _clearLookupResult();
                          });
                        },
                        icon: const Icon(Icons.close, color: Color(0xFF607080)),
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
              ),
              onChanged: _onHeroQueryChanged,
            ),
          ),
          const SizedBox(height: 16),
          _buildAirlineFilterRow(),
          if (kDebugMode && !_didLoadDebugHiddenEntries) ...[
            const SizedBox(height: 12),
            const Text(
              'Loading debug catalog controls...',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFD6E0E7),
              ),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Suggestions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ...suggestions.map(_buildSuggestionTile),
          ],
        ],
      ),
    );
  }

  Widget _buildAirlineFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._airlineFilters.expand((airline) => [
                _buildAirlineChip(
                  label: airline,
                  isSelected: _selectedAirlineFilter == airline,
                ),
                const SizedBox(width: 8),
              ]),
        ],
      ),
    );
  }

  Widget _buildAirlineChip({
    required String label,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedAirlineFilter = label;
        });
        _verifyVisibleCatalogEntries();
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primaryGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(
        color: isSelected ? AppColors.primaryGreen : Colors.transparent,
      ),
    );
  }

  Widget _buildSuggestionTile(FlightCatalogEntry entry) {
    final verificationStatus = _verificationStatusFor(entry);
    final isInvalid = verificationStatus == _CatalogVerificationStatus.invalid;
    final isVerifying = verificationStatus == _CatalogVerificationStatus.verifying;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isInvalid ? null : () => _selectCatalogFlight(entry),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.flightCode} • ${entry.airlineName}',
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.routeCodeLabel} • ${entry.routeCityLabel}',
                        style: const TextStyle(
                          color: Color(0xFF6D7B88),
                          fontSize: 13,
                        ),
                      ),
                      if (isVerifying) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Checking with Travel Impact Model...',
                          style: TextStyle(
                            color: AppColors.warningOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (isInvalid && kDebugMode) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'No Travel Impact Model result found for this flight.',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isVerifying)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warningOrange,
                    ),
                  )
                else if (isInvalid && kDebugMode)
                  IconButton(
                    onPressed: () => _hideCatalogEntry(entry),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.errorRed,
                    ),
                    tooltip: 'Hide invalid catalog entry in debug',
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF9AA7B4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'These settings are used when you tap a suggested flight or browse the catalog.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF6D7B88),
            ),
          ),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildCabinClassSelector(),
        ],
      ),
    );
  }

  Widget _buildFlightCatalogCard() {
    final flights = _catalogFlights;
    final hasQuery = _heroSearchController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Browse flights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (_selectedAirlineFilter != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _selectedAirlineFilter!,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Tap a match to autofill the flight and run the emissions lookup.'
                : 'Featured flights make it easy to try the app quickly.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF6D7B88),
            ),
          ),
          const SizedBox(height: 16),
          if (flights.isEmpty)
            _buildCatalogEmptyState()
          else
            ...flights.map(_buildCatalogTile),
        ],
      ),
    );
  }

  Widget _buildCatalogEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 34, color: Color(0xFF9AA7B4)),
          SizedBox(height: 10),
          Text(
            'No flights matched that search.',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try another airline, route, or flight number.',
            style: TextStyle(
              color: Color(0xFF6D7B88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTile(FlightCatalogEntry entry) {
    final isSelected = _selectedCatalogEntry == entry;
    final verificationStatus = _verificationStatusFor(entry);
    final isInvalid = verificationStatus == _CatalogVerificationStatus.invalid;
    final isVerifying = verificationStatus == _CatalogVerificationStatus.verifying;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isInvalid ? null : () => _selectCatalogFlight(entry),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGreen
                    : const Color(0xFFE1E6EC),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.flightCode} • ${entry.airlineName}',
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (entry.isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (isVerifying)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.warningOrange,
                        ),
                      )
                    else if (isInvalid && kDebugMode)
                      IconButton(
                        onPressed: () => _hideCatalogEntry(entry),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.errorRed,
                        ),
                        tooltip: 'Hide invalid catalog entry in debug',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${entry.originCity} (${entry.originCode}) to ${entry.destinationCity} (${entry.destinationCode})',
                  style: const TextStyle(
                    color: Color(0xFF6D7B88),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildCatalogMetric('From', entry.originCode),
                    const SizedBox(width: 12),
                    _buildCatalogMetric('To', entry.destinationCode),
                    const SizedBox(width: 12),
                    _buildCatalogMetric('Airline', entry.carrierCode),
                  ],
                ),
                if (isVerifying) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Checking this catalog row against the Travel Impact Model...',
                    style: TextStyle(
                      color: AppColors.warningOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (isInvalid && kDebugMode) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'No valid Travel Impact Model result. You can hide this row in debug mode.',
                    style: TextStyle(
                      color: AppColors.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8A97A3),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _manualEntryExpanded = !_manualEntryExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter flight manually',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Use this if you already know the exact flight details.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _manualEntryExpanded ? Icons.remove : Icons.add,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          if (_manualEntryExpanded) ...[
            const Divider(height: 1, color: Color(0xFF304356)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFlightNumberField(),
                  const SizedBox(height: 16),
                  _buildRouteInputs(),
                  const SizedBox(height: 16),
                  _buildLookupButton(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlightNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flight Number',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('✈  ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: TextField(
                  controller: _flightNumberController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. UA 857',
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _errorMessage = null;
                      _selectedCatalogEntry = null;
                      _clearLookupResult();
                    });
                  },
                  onSubmitted: (_) => _lookupFlight(),
                ),
              ),
              if (_hasResult)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteInputs() {
    return Row(
      children: [
        Expanded(
          child: _buildAirportCodeField(
            label: 'Origin',
            controller: _originController,
            hintText: 'e.g. SFO',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAirportCodeField(
            label: 'Destination',
            controller: _destinationController,
            hintText: 'e.g. JFK',
          ),
        ),
      ],
    );
  }

  Widget _buildAirportCodeField({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
            ),
            onChanged: (_) {
              setState(() {
                _errorMessage = null;
                _selectedCatalogEntry = null;
                _clearLookupResult();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final dateStr = DateFormat('MMMM d, yyyy').format(_selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flight Date',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6D7B88),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Color(0xFF757575),
                ),
                const SizedBox(width: 12),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCabinClassSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cabin Class',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6D7B88),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: CabinClass.values.map((cabin) {
              final isSelected = cabin == _selectedCabin;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onCabinChanged(cabin),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cabin == CabinClass.premiumEconomy
                          ? 'Prem.'
                          : cabin.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLookupButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _lookupFlight,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardBackground,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.search, size: 20),
        label: const Text(
          'Look Up Flight',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFE53935),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$_airlineCode $_flightNum',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF388E3C),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _origin,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFFE0E0E0),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.flight,
                        size: 20,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFFE0E0E0),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _destination,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlightDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDetailItem('Airline', _airlineCode)),
              Expanded(
                child: _buildDetailItem('Flight', '$_airlineCode $_flightNum'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Date',
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                ),
              ),
              Expanded(
                child: _buildDetailItem('Class', _selectedCabin.displayName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildEmissionsCard() {
    final tons = (_emissionsKg / 1000).toStringAsFixed(2);
    final equivalentMiles = (_emissionsKg * 2.51).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _usedTypicalFallback
                ? 'Estimated Carbon Emission (route average)'
                : 'Estimated Carbon Emission',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: tons,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const TextSpan(
                  text: ' tons CO\u2082',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Equivalent to driving ${NumberFormat('#,###').format(equivalentMiles)} miles',
            style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _addToFlightLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add, size: 20),
        label: Text(
          _isSaving ? 'Saving...' : 'Add to Flight Log',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum _CatalogVerificationStatus {
  unverified,
  verifying,
  valid,
  invalid,
}
