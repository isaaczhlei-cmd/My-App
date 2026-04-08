import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/emissions_service.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_bottom_nav.dart';

class AddFlightScreen extends StatefulWidget {
  const AddFlightScreen({super.key});

  @override
  State<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends State<AddFlightScreen> {
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
  String? _errorMessage;

  // Real API result data
  String _origin = '';
  String _destination = '';
  String _airlineCode = '';
  int _flightNum = 0;
  double _emissionsKg = 0;
  CabinClass _selectedCabin = CabinClass.economy;

  // Emissions by class (from API)
  FlightEmission? _flightEmission;
  TypicalRouteEmission? _typicalEmission;
  bool _usedTypicalFallback = false;

  @override
  void dispose() {
    _flightNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  /// Parse "UA 857" or "UA857" into carrier code + number
  ({String carrier, int number})? _parseFlightNumber(String input) {
    final cleaned = input.trim().toUpperCase();
    // Match patterns like "UA 857", "UA857", "UA-857"
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

    // Try specific flight lookup first
    final result = await _emissionsService.computeFlightEmissions(
      origin: origin,
      destination: destination,
      operatingCarrierCode: parsed.carrier,
      flightNumber: parsed.number,
      departureDate: _selectedDate,
    );

    if (!mounted) return;

    // Check if we got real emissions data (not 0)
    if (result != null && result.flightEmissions.isNotEmpty) {
      final emission = result.flightEmissions.first;
      final kg = emission.getEmissionsKg(_selectedCabin);

      if (kg > 0) {
        // Specific flight data worked
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

    // Fallback: use typical route emissions (works for any airport pair)
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
    }
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

    // Reset form
    setState(() {
      _clearLookupResult();
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
              const Text(
                'Add Flight',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildFlightNumberField(),
              const SizedBox(height: 16),
              _buildRouteInputs(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildCabinClassSelector(),
              const SizedBox(height: 16),
              _buildLookupButton(),
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
                      _clearLookupResult();
                    });
                  },
                  onSubmitted: (_) => _lookupFlight(),
                ),
              ),
              if (_hasResult)
                const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 22),
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
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Color(0xFF757575)),
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
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
                      color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cabin == CabinClass.premiumEconomy ? 'Prem.' : cabin.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : const Color(0xFF757575),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.search, size: 20),
        label: const Text('Look Up Flight', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
              Column(
                children: [
                  Text(
                    _origin,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: const Color(0xFFE0E0E0))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.flight, size: 20, color: Color(0xFF9E9E9E)),
                        ),
                        Expanded(child: Container(height: 1, color: const Color(0xFFE0E0E0))),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
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
              Expanded(child: _buildDetailItem('Flight', '$_airlineCode $_flightNum')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Date', DateFormat('MMM d, yyyy').format(_selectedDate))),
              Expanded(child: _buildDetailItem('Class', _selectedCabin.displayName)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }

  Widget _buildEmissionsCard() {
    final tons = (_emissionsKg / 1000).toStringAsFixed(2);
    final equivalentMiles = (_emissionsKg * 2.51).round(); // ~2.51 driving miles per kg CO2

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
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add, size: 20),
        label: Text(
          _isSaving ? 'Saving...' : 'Add to Flight Log',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
