import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../widgets/app_bottom_nav.dart';

class AddFlightScreen extends StatefulWidget {
  const AddFlightScreen({super.key});

  @override
  State<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends State<AddFlightScreen> {
  final _flightNumberController = TextEditingController();
  DateTime _selectedDate = DateTime(2024, 11, 20);
  bool _hasResult = false;
  bool _isLoading = false;

  // TODO: Replace with real API data from EmmisonService
  final _mockResult = _MockFlightResult(
    origin: 'SFO',
    originCity: 'San Francisco',
    destination: 'PEK',
    destinationCity: 'Beijing',
    distanceMi: 5918,
    airline: 'United Airlines',
    aircraft: 'Boeing 777-300',
    duration: '13h 25m',
    travelClass: 'Economy',
    emissionsTons: 1.18,
    equivalentMiles: 2960,
  );

  @override
  void initState() {
    super.initState();
    _flightNumberController.text = 'UA 857';
    _hasResult = true; // Show mock result by default for demo
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    super.dispose();
  }

  Future<void> _lookupFlight() async {
    if (_flightNumberController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    // TODO: Call EmmisonService.computeFlightEmissions() here
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _hasResult = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      setState(() => _selectedDate = picked);
    }
  }

  void _addToFlightLog() {
    // TODO: Save flight to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flight added to your log!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
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
              _buildFlightNumberField(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 24),
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
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
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
              const Text(
                '✈  ',
                style: TextStyle(fontSize: 16),
              ),
              Expanded(
                child: TextField(
                  controller: _flightNumberController,
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

  Widget _buildDateField() {
    final dateStr = DateFormat('MMMM d, yyyy').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flight Date',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
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
          // Outbound label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Outbound',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE53935),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Route visualization
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Origin
              Column(
                children: [
                  Text(
                    _mockResult.origin,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    _mockResult.originCity,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              // Flight path
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFE0E0E0),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.flight, size: 20, color: Color(0xFF9E9E9E)),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFE0E0E0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,###').format(_mockResult.distanceMi)} mi',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
              // Destination
              Column(
                children: [
                  Text(
                    _mockResult.destination,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    _mockResult.destinationCity,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
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
              Expanded(
                child: _buildDetailItem('Airline', _mockResult.airline),
              ),
              Expanded(
                child: _buildDetailItem('Aircraft', _mockResult.aircraft),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Duration', _mockResult.duration),
              ),
              Expanded(
                child: _buildDetailItem('Class', _mockResult.travelClass),
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
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9E9E9E),
          ),
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
          const Text(
            'Estimated Carbon Emission',
            style: TextStyle(
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
                  text: '${_mockResult.emissionsTons}',
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
            'Equivalent to driving ${NumberFormat('#,###').format(_mockResult.equivalentMiles)} miles',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF757575),
            ),
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
        onPressed: _addToFlightLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Add to Flight Log',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Temporary mock data class — will be replaced by EmmisonService results
class _MockFlightResult {
  final String origin;
  final String originCity;
  final String destination;
  final String destinationCity;
  final int distanceMi;
  final String airline;
  final String aircraft;
  final String duration;
  final String travelClass;
  final double emissionsTons;
  final int equivalentMiles;

  const _MockFlightResult({
    required this.origin,
    required this.originCity,
    required this.destination,
    required this.destinationCity,
    required this.distanceMi,
    required this.airline,
    required this.aircraft,
    required this.duration,
    required this.travelClass,
    required this.emissionsTons,
    required this.equivalentMiles,
  });
}
