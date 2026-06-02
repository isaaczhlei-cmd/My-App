import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AddFlightScreenState extends State<AddFlightScreen>
    with SingleTickerProviderStateMixin {
  static const _hiddenCatalogPrefsKey = 'debug_hidden_flight_catalog_entries';

  final _heroSearchController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _passengerCountController = TextEditingController(text: '1');
  final _emissionsService = EmissionsService();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  late final AnimationController _swapAnimationController;
  late final Animation<double> _swapRotationAnimation;

  DateTime _selectedDate = DateTime.now();
  bool _hasResult = false;
  bool _isLoading = false;
  bool _isSaving = false;
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
    _swapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _swapRotationAnimation = CurvedAnimation(
      parent: _swapAnimationController,
      curve: Curves.easeInOut,
    );
    _loadHiddenCatalogEntries();
  }

  @override
  void dispose() {
    _swapAnimationController.dispose();
    _heroSearchController.dispose();
    _flightNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _passengerCountController.dispose();
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

  int? _parsePassengerCount() {
    final count = int.tryParse(_passengerCountController.text.trim());
    if (count == null || count < 1) return null;
    return count;
  }

  double _totalEmissionsKg(double kgPerPassenger) {
    return kgPerPassenger * (_parsePassengerCount() ?? 1);
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

  List<FlightCatalogEntry> _filterVerifiedEntries(
    List<FlightCatalogEntry> entries,
  ) {
    if (kDebugMode) return entries;
    return entries.where((entry) {
      return _verificationStatusFor(entry) !=
          _CatalogVerificationStatus.invalid;
    }).toList();
  }

  Future<void> _lookupFlight() async {
    final origin = _parseAirportCode(_originController.text);
    final destination = _parseAirportCode(_destinationController.text);
    if (origin == null || destination == null) {
      setState(() {
        _errorMessage = 'Enter valid 3-letter airport codes like SFO and JFK';
        _clearLookupResult();
      });
      return;
    }

    final passengerCount = _parsePassengerCount();
    if (passengerCount == null) {
      setState(() {
        _errorMessage = 'Enter at least 1 passenger.';
        _clearLookupResult();
      });
      return;
    }

    final flightNumber = _flightNumberController.text.trim();
    final parsed = flightNumber.isEmpty
        ? null
        : _parseFlightNumber(flightNumber);
    if (flightNumber.isNotEmpty && parsed == null) {
      setState(() {
        _errorMessage =
            'Enter a valid flight number like UA 857, or leave it blank.';
        _clearLookupResult();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _clearLookupResult();
    });

    final typicalEmissionFuture = _emissionsService.computeTypicalEmissions(
      origin: origin,
      destination: destination,
    );

    if (parsed != null) {
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
            _airlineCode =
                emission.flight?.operatingCarrierCode ?? parsed.carrier;
            _flightNum = emission.flight?.flightNumber ?? parsed.number;
            _emissionsKg = kg * passengerCount;
            _usedTypicalFallback = false;
            _isLoading = false;
            _hasResult = true;
          });
          return;
        }
      }
    }

    final typicalResult = await typicalEmissionFuture;

    if (!mounted) return;

    if (typicalResult != null && typicalResult.typicalEmissions.isNotEmpty) {
      final typical = typicalResult.typicalEmissions.first;
      final kg = typical.getEmissionsKg(_selectedCabin);

      setState(() {
        _typicalEmission = typical;
        _origin = origin;
        _destination = destination;
        _airlineCode = parsed?.carrier ?? '';
        _flightNum = parsed?.number ?? 0;
        _emissionsKg = kg * passengerCount;
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
        _emissionsKg = _totalEmissionsKg(
          _flightEmission!.getEmissionsKg(cabin),
        );
      } else if (_typicalEmission != null) {
        _emissionsKg = _totalEmissionsKg(
          _typicalEmission!.getEmissionsKg(cabin),
        );
      }
    });
  }

  void _onPassengerCountChanged(String value) {
    setState(() {
      _errorMessage = null;
      if (_flightEmission != null) {
        _emissionsKg = _totalEmissionsKg(
          _flightEmission!.getEmissionsKg(_selectedCabin),
        );
      } else if (_typicalEmission != null) {
        _emissionsKg = _totalEmissionsKg(
          _typicalEmission!.getEmissionsKg(_selectedCabin),
        );
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

  void _swapRoute() {
    final origin = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = origin;
    _swapAnimationController.forward(from: 0);
    setState(() {
      _errorMessage = null;
      _selectedCatalogEntry = null;
      _clearLookupResult();
    });
  }

  Future<void> _selectCatalogFlight(FlightCatalogEntry entry) async {
    setState(() {
      _selectedCatalogEntry = entry;
      _heroSearchController.text = entry.flightCode;
      _flightNumberController.text = entry.compactFlightCode;
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
    });
    _verifyVisibleCatalogEntries();
  }

  Future<void> _hideCatalogEntry(FlightCatalogEntry entry) async {
    if (!kDebugMode) return;
    final nextHidden = {..._hiddenCatalogEntryIds, entry.id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hiddenCatalogPrefsKey,
      nextHidden.toList()..sort(),
    );
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
          (_verificationStatusByKey.containsKey(key) ||
              _activeVerificationKeys.contains(key))) {
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
      _verificationStatusByKey[key] = isValid
          ? _CatalogVerificationStatus.valid
          : _CatalogVerificationStatus.invalid;
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
      AirlineNumber: _flightNum > 0 ? _flightNum.toString() : '',
    );

    await _firestoreService.addFlight(flight);

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Flight added to your log!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    setState(() {
      _clearLookupResult();
      _selectedCatalogEntry = null;
      _heroSearchController.clear();
      _flightNumberController.clear();
      _originController.clear();
      _destinationController.clear();
      _passengerCountController.text = '1';
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
              const SizedBox(height: 18),
              _buildFindFlightCard(),
              const SizedBox(height: 20),
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
          'Search the catalog or enter route details manually.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFindFlightCard() {
    final flights = _catalogFlights;
    final hasQuery = _heroSearchController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your flight fast',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          _buildAirportCodeField(
            label: 'From',
            controller: _originController,
            hintText: 'Departing airport',
            icon: Icons.radio_button_checked,
            backgroundColor: AppColors.surface,
            borderColor: const Color(0xFF3A4B5C),
            labelColor: AppColors.textSecondary,
            textColor: Colors.white,
            hintColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Center(
            child: IconButton.filled(
              onPressed: _swapRoute,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primaryGreen,
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0xFF3A4B5C)),
                ),
              ),
              tooltip: 'Swap route',
              icon: RotationTransition(
                turns: _swapRotationAnimation,
                child: const Icon(Icons.swap_vert, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildAirportCodeField(
            label: 'To',
            controller: _destinationController,
            hintText: 'Arriving airport',
            icon: Icons.location_on_outlined,
            backgroundColor: AppColors.surface,
            borderColor: const Color(0xFF3A4B5C),
            labelColor: AppColors.textSecondary,
            textColor: Colors.white,
            hintColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          _buildDateField(
            backgroundColor: AppColors.surface,
            labelColor: AppColors.textSecondary,
            borderColor: const Color(0xFF3A4B5C),
            textColor: Colors.white,
          ),
          const SizedBox(height: 14),
          _buildPassengerCountField(),
          const SizedBox(height: 14),
          _buildCabinClassSelector(
            backgroundColor: AppColors.surface,
            labelColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFF3A4B5C)),
          const SizedBox(height: 18),
          _buildCatalogSearchField(),
          const SizedBox(height: 12),
          _buildAirlineFilterRow(),
          const SizedBox(height: 14),
          Text(
            hasQuery
                ? 'Tap a match to autofill the route and airline details.'
                : 'Featured flights appear here. Search CX881, Cathay, or LAX to HKG.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (flights.isEmpty)
            _buildCatalogEmptyState()
          else
            ...flights.map(_buildCatalogTile),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFF3A4B5C)),
          const SizedBox(height: 18),
          _buildOptionalAirlineSection(),
          const SizedBox(height: 16),
          _buildLookupButton(),
        ],
      ),
    );
  }

  Widget _buildOptionalAirlineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x1A64B067),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.airlines,
                color: AppColors.primaryGreen,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual enter flight',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFlightNumberField(
          labelColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          borderColor: const Color(0xFF3A4B5C),
          textColor: Colors.white,
          hintColor: AppColors.textSecondary,
          hintText: 'Flight number',
        ),
      ],
    );
  }

  Widget _buildAirlineFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._airlineFilters.expand(
            (airline) => [
              _buildAirlineChip(
                label: airline,
                isSelected: _selectedAirlineFilter == airline,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAirlineChip({required String label, required bool isSelected}) {
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
      selectedColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
      ),
    );
  }

  Widget _buildCatalogSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _heroSearchController,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search airline, flight, or route',
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
                    _verifyVisibleCatalogEntries();
                  },
                  icon: const Icon(Icons.close, color: Color(0xFF607080)),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: _onHeroQueryChanged,
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
            style: TextStyle(color: Color(0xFF6D7B88)),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTile(FlightCatalogEntry entry) {
    final isSelected = _selectedCatalogEntry == entry;
    final verificationStatus = _verificationStatusFor(entry);
    final isInvalid = verificationStatus == _CatalogVerificationStatus.invalid;
    final isVerifying =
        verificationStatus == _CatalogVerificationStatus.verifying;

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
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A97A3)),
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

  Widget _buildFlightNumberField({
    Color backgroundColor = const Color(0xFFF6F8FA),
    Color borderColor = Colors.transparent,
    Color labelColor = const Color(0xFF6D7B88),
    Color textColor = const Color(0xFF1A1A2E),
    Color hintColor = const Color(0xFFBDBDBD),
    String hintText = 'e.g. UA 857',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flight Number',
          style: TextStyle(fontSize: 14, color: labelColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _flightNumberController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ).copyWith(color: textColor),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(color: hintColor),
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

  Widget _buildPassengerCountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passengers',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: const Color(0xFF3A4B5C)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passengerCountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'How many people?',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  onChanged: _onPassengerCountChanged,
                  onSubmitted: (_) => _lookupFlight(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAirportCodeField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    Color backgroundColor = const Color(0xFFF6F8FA),
    Color borderColor = Colors.transparent,
    Color labelColor = const Color(0xFF6D7B88),
    Color textColor = const Color(0xFF1A1A2E),
    Color hintColor = const Color(0xFFBDBDBD),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: labelColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: hintText,
                    hintStyle: TextStyle(color: hintColor),
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
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    Color backgroundColor = const Color(0xFFF6F8FA),
    Color labelColor = const Color(0xFF6D7B88),
    Color borderColor = Colors.transparent,
    Color textColor = const Color(0xFF1A1A2E),
  }) {
    final dateStr = DateFormat('MMMM d, yyyy').format(_selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Flight Date', style: TextStyle(fontSize: 14, color: labelColor)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCabinClassSelector({
    Color backgroundColor = const Color(0xFFF6F8FA),
    Color labelColor = const Color(0xFF6D7B88),
  }) {
    final cabins = CabinClass.values;
    final selectedIndex = cabins.indexOf(_selectedCabin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cabin Class', style: TextStyle(fontSize: 14, color: labelColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / cabins.length;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: segmentWidth * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: cabins.map((cabin) {
                      final isSelected = cabin == _selectedCabin;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            splashColor: Theme.of(context).colorScheme.primary.withValues(
                              alpha: 0.14,
                            ),
                            highlightColor: Colors.transparent,
                            onTap: () => _onCabinChanged(cabin),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF757575),
                                ),
                                child: Text(
                                  cabin == CabinClass.premiumEconomy
                                      ? 'Prem.'
                                      : cabin.displayName,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
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
            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFE53935), fontSize: 14),
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
    final flightLabel = _flightNum > 0
        ? '$_airlineCode $_flightNum'
        : 'Route average';

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
              flightLabel,
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
    final airlineValue = _airlineCode.isEmpty ? 'Not specified' : _airlineCode;
    final flightValue = _flightNum > 0
        ? '$_airlineCode $_flightNum'
        : 'Route average';

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
              Expanded(child: _buildDetailItem('Airline', airlineValue)),
              Expanded(child: _buildDetailItem('Flight', flightValue)),
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
    final passengerCount = _parsePassengerCount() ?? 1;

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
                ? 'Estimated Carbon Emission for $passengerCount ${passengerCount == 1 ? 'passenger' : 'passengers'} (route average)'
                : 'Estimated Carbon Emission for $passengerCount ${passengerCount == 1 ? 'passenger' : 'passengers'}',
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
                  style: TextStyle(fontSize: 18, color: Color(0xFF1A1A2E)),
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
          backgroundColor: Theme.of(context).colorScheme.primary,
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

enum _CatalogVerificationStatus { unverified, verifying, valid, invalid }
