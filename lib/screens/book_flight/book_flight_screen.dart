import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../services/emissions_service.dart';
import '../../widgets/app_bottom_nav.dart';
import 'airport_directory.dart';
import 'booking_handoff_screen.dart';

class BookFlightScreen extends StatefulWidget {
  const BookFlightScreen({super.key});

  @override
  State<BookFlightScreen> createState() => _BookFlightScreenState();
}

class _BookFlightScreenState extends State<BookFlightScreen> {
  bool _isRoundTrip = true;
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
  DateTime _departDate = DateTime(2026, 4, 15);
  DateTime _returnDate = DateTime(2026, 4, 22);
  int _passengers = 1;
  CabinClass _selectedCabin = CabinClass.economy;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: _fromAirport.shortLabel);
    _toController = TextEditingController(text: _toAirport.shortLabel);

    _fromFocusNode.addListener(_handleFocusChange);
    _toFocusNode.addListener(_handleFocusChange);
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
    final initialDate = isReturn ? _returnDate : _departDate;
    final firstDate = isReturn ? _departDate : DateTime(2025);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2030),
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

    setState(() {
      if (isReturn) {
        _returnDate = selected;
      } else {
        _departDate = selected;
        if (_returnDate.isBefore(_departDate)) {
          _returnDate = _departDate.add(const Duration(days: 7));
        }
      }
    });
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
  }

  Future<void> _runSearch() async {
    final fromMatch = AirportDirectory.findBestMatch(
      _fromController.text,
      excludeCode: _toAirport.code,
    );
    final toMatch = AirportDirectory.findBestMatch(
      _toController.text,
      excludeCode: _fromAirport.code,
    );

    if (fromMatch == null || toMatch == null) {
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
      _hasSearched = true;
      _fromMatches = const [];
      _toMatches = const [];
    });

    final outboundUrl = _buildFlightSearchUri(
      origin: fromMatch.code,
      destination: toMatch.code,
      departureDate: _departDate,
    );

    if (!_isRoundTrip) {
      await _launchExternalSearch(outboundUrl);
      return;
    }

    final returnUrl = _buildFlightSearchUri(
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

  @override
  Widget build(BuildContext context) {
    final offers = _buildOffers();
    final ecoRoute = offers.reduce(
      (current, next) => current.emissionsKg <= next.emissionsKg ? current : next,
    );

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildBookingCard(),
              const SizedBox(height: 20),
              _buildEcoRouteCard(ecoRoute),
              const SizedBox(height: 20),
              _buildCheapestOptions(offers),
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
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFDCE2FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            hintText: 'Type city, airport name, or code',
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
                color: const Color(0xFFF1F3F8),
                borderRadius: BorderRadius.circular(22),
              ),
              child: IconButton(
                onPressed: _swapAirports,
                icon: const Icon(Icons.swap_vert, color: Color(0xFF30324A)),
              ),
            ),
          ),
          const SizedBox(height: 2),
          _buildFieldLabel(Icons.flight_land, 'To'),
          const SizedBox(height: 8),
          _buildAirportInput(
            controller: _toController,
            focusNode: _toFocusNode,
            hintText: 'Type city, airport name, or code',
            matches: _toMatches,
            onChanged: (value) => _updateAirportMatches(value, isFrom: false),
            onSelected: (airport) => _selectAirport(airport, isFrom: false),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Depart',
                  date: _departDate,
                  onTap: () => _selectDate(isReturn: false),
                ),
              ),
              if (_isRoundTrip) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Return',
                    date: _returnDate,
                    onTap: () => _selectDate(isReturn: true),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _runSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A0B1C),
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
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E8EE),
        borderRadius: BorderRadius.circular(18),
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
                  color: _isRoundTrip ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Round Trip',
                    style: TextStyle(
                      color: const Color(0xFF30324A),
                      fontWeight: _isRoundTrip ? FontWeight.w700 : FontWeight.w600,
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
                  color: !_isRoundTrip ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'One Way',
                    style: TextStyle(
                      color: const Color(0xFF30324A),
                      fontWeight: !_isRoundTrip ? FontWeight.w700 : FontWeight.w600,
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
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF30324A)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF30324A),
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
    return Column(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFF30324A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF8A8FA7),
              fontSize: 15,
            ),
            filled: true,
            fillColor: const Color(0xFFF2F3F7),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF737896)),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close, color: Color(0xFF737896)),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
          ),
        ),
        if (focusNode.hasFocus && matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E5EE)),
            ),
            child: Column(
              children: matches.map((airport) {
                return ListTile(
                  leading: const Icon(
                    Icons.flight,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(
                    airport.shortLabel,
                    style: const TextStyle(
                      color: Color(0xFF30324A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${airport.name} • ${airport.country}',
                    style: const TextStyle(color: Color(0xFF737896)),
                  ),
                  onTap: () => onSelected(airport),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
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
              color: const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(
                      color: Color(0xFF30324A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Color(0xFFB3B7C7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _passengers > 1
                ? () {
                    setState(() {
                      _passengers -= 1;
                    });
                  }
                : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: const Color(0xFF30324A),
          ),
          Expanded(
            child: Text(
              '$_passengers',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF30324A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _passengers += 1;
              });
            },
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFF30324A),
          ),
        ],
      ),
    );
  }

  Widget _buildCabinClassSelector() {
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
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryGreen : const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              cabin.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF30324A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEcoRouteCard(_FlightOffer ecoRoute) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.eco, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Most Eco-Friendly Route',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildBadge('Lowest CO2', AppColors.primaryGreen),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${ecoRoute.airline} • ${ecoRoute.stopsLabel}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ecoRoute.routeDescription,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  label: 'Carbon',
                  value: '${ecoRoute.emissionsKg.toStringAsFixed(0)} kg CO2',
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: 'Duration',
                  value: ecoRoute.durationLabel,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: 'Price',
                  value: _formatPrice(ecoRoute.price),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheapestOptions(List<_FlightOffer> offers) {
    final sortedByPrice = [...offers]..sort((a, b) => a.price.compareTo(b.price));

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
                  'Cheapest Options',
                  style: TextStyle(
                    color: Color(0xFF10131E),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_hasSearched)
                const Text(
                  'Updated',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on ${_selectedCabin.displayName.toLowerCase()} fares for $_passengers passenger${_passengers == 1 ? '' : 's'}.',
            style: const TextStyle(
              color: Color(0xFF737896),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < sortedByPrice.length; i++) ...[
            _buildOfferTile(sortedByPrice[i], isCheapest: i == 0),
            if (i != sortedByPrice.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferTile(_FlightOffer offer, {required bool isCheapest}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCheapest
              ? AppColors.primaryGreen.withValues(alpha: 0.45)
              : const Color(0xFFE2E5EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.airline,
                  style: const TextStyle(
                    color: Color(0xFF10131E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isCheapest) _buildBadge('Cheapest', AppColors.primaryGreen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            offer.routeDescription,
            style: const TextStyle(color: Color(0xFF737896)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildLightMetric(
                  label: 'Fare',
                  value: _formatPrice(offer.price),
                ),
              ),
              Expanded(
                child: _buildLightMetric(
                  label: 'Emissions',
                  value: '${offer.emissionsKg.toStringAsFixed(0)} kg',
                ),
              ),
              Expanded(
                child: _buildLightMetric(
                  label: 'Trip',
                  value: offer.stopsLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLightMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A8FA7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF10131E),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<_FlightOffer> _buildOffers() {
    final distanceKm = _distanceKm(_fromAirport, _toAirport);
    final tripMultiplier = _isRoundTrip ? 1.82 : 1.0;
    final cabinPriceMultiplier = switch (_selectedCabin) {
      CabinClass.economy => 1.0,
      CabinClass.premiumEconomy => 1.35,
      CabinClass.business => 2.2,
      CabinClass.first => 3.1,
    };
    final cabinEmissionMultiplier = switch (_selectedCabin) {
      CabinClass.economy => 1.0,
      CabinClass.premiumEconomy => 1.28,
      CabinClass.business => 1.85,
      CabinClass.first => 2.45,
    };
    final passengerMultiplier = math.max(1, _passengers).toDouble();
    final basePrice = (58 + distanceKm * 0.092) * tripMultiplier * cabinPriceMultiplier;
    final baseEmissions = distanceKm * 0.115 * tripMultiplier * cabinEmissionMultiplier;
    final baseDurationHours = distanceKm / 790;

    return [
      _FlightOffer(
        airline: 'BudgetSky',
        price: basePrice * 0.86 * passengerMultiplier,
        emissionsKg: baseEmissions * 1.12 * passengerMultiplier,
        durationHours: baseDurationHours + 2.1,
        stopsLabel: '1 stop',
        routeDescription: '${_fromAirport.code} → ${_toAirport.code}',
      ),
      _FlightOffer(
        airline: 'CoastAir',
        price: basePrice * 1.03 * passengerMultiplier,
        emissionsKg: baseEmissions * 0.96 * passengerMultiplier,
        durationHours: baseDurationHours + 0.4,
        stopsLabel: 'Direct',
        routeDescription: '${_fromAirport.code} → ${_toAirport.code}',
      ),
      _FlightOffer(
        airline: 'EcoWings',
        price: basePrice * 1.11 * passengerMultiplier,
        emissionsKg: baseEmissions * 0.79 * passengerMultiplier,
        durationHours: baseDurationHours + 0.9,
        stopsLabel: 'Direct',
        routeDescription: '${_fromAirport.code} → ${_toAirport.code}',
      ),
    ];
  }

  double _distanceKm(AirportOption from, AirportOption to) {
    const earthRadiusKm = 6371.0;
    final lat1 = _degreesToRadians(from.latitude);
    final lon1 = _degreesToRadians(from.longitude);
    final lat2 = _degreesToRadians(to.latitude);
    final lon2 = _degreesToRadians(to.longitude);

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  String _formatPrice(double value) {
    return '\$${value.round()}';
  }

  Uri _buildFlightSearchUri({
    required String origin,
    required String destination,
    required DateTime departureDate,
  }) {
    return Uri.https(
      'www.skyscanner.net',
      '/g/referrals/v1/flights/day-view/',
      <String, String>{
        'origin': origin,
        'destination': destination,
        'outboundDate': _formatIsoDate(departureDate),
        'adultsv2': '$_passengers',
        'cabinclass': _skyscannerCabinClass(_selectedCabin),
        'market': 'US',
        'locale': 'en-US',
        'currency': 'USD',
      },
    );
  }

  Future<void> _launchExternalSearch(Uri url) async {
    final success = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the flight search site.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _skyscannerCabinClass(CabinClass cabinClass) {
    return switch (cabinClass) {
      CabinClass.economy => 'economy',
      CabinClass.premiumEconomy => 'premiumeconomy',
      CabinClass.business => 'business',
      CabinClass.first => 'first',
    };
  }
}

class _FlightOffer {
  const _FlightOffer({
    required this.airline,
    required this.price,
    required this.emissionsKg,
    required this.durationHours,
    required this.stopsLabel,
    required this.routeDescription,
  });

  final String airline;
  final double price;
  final double emissionsKg;
  final double durationHours;
  final String stopsLabel;
  final String routeDescription;

  String get durationLabel {
    final totalMinutes = (durationHours * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
