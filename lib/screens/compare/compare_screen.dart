import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_bottom_nav.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _firestoreService = FirestoreService();

  bool _isInCurrentYear(DateTime date, DateTime now) {
    return date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final flights = (snapshot.data ?? [])
                .where((flight) => _isInCurrentYear(flight.date, now))
                .toList();
            final totalKg = flights.fold<double>(
              0,
              (sum, f) => sum + f.emissionsKg,
            );
            final totalTons = totalKg / 1000;

            // Average American flies ~3 round trips/year ≈ 1.82 tons CO2
            const avgTons = 1.82;
            final percentDiff = avgTons > 0
                ? (((avgTons - totalTons) / avgTons) * 100).round().abs()
                : 0;
            final isBelow = totalTons < avgTons;

            // Environmental equivalents (based on EPA factors)
            final milesDriven = (totalKg * 2.51).round();
            final monthsElectricity = (totalKg / 280).toStringAsFixed(1);
            final trees = (totalKg / 22).round();
            final burgers = (totalKg / 2.5).round();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compare',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (flights.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildCarbonImpactCard(
                      totalTons,
                      avgTons,
                      percentDiff,
                      isBelow,
                    ),
                    const SizedBox(height: 20),
                    _buildEnvironmentalEquivalents(
                      milesDriven: milesDriven,
                      monthsElectricity: monthsElectricity,
                      trees: trees,
                      burgers: burgers,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.compare_arrows, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No flights this year',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add flights from this year to see how your annual carbon footprint compares to the average.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbonImpactCard(
    double yourTons,
    double avgTons,
    int percentDiff,
    bool isBelow,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Carbon Impact',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _GaugePainter(
                    value: yourTons,
                    maxValue: max(avgTons * 1.3, yourTons * 1.1),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          yourTons.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const Text(
                          'tons',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildComparisonRow(
                      'Your annual total',
                      '${yourTons.toStringAsFixed(2)}t CO\u2082',
                      AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    _buildComparisonRow(
                      'Avg. American/year',
                      '${avgTons}t CO\u2082',
                      const Color(0xFFFF8F00),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBelow
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBelow ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: isBelow
                      ? AppColors.primaryGreen
                      : const Color(0xFFFF8F00),
                ),
                const SizedBox(width: 4),
                Text(
                  '$percentDiff% ${isBelow ? 'below' : 'above'} average',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isBelow
                        ? AppColors.primaryGreen
                        : const Color(0xFFFF8F00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnvironmentalEquivalents({
    required int milesDriven,
    required String monthsElectricity,
    required int trees,
    required int burgers,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Environmental Equivalents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildEquivalentItem(
                  Icons.directions_car,
                  '$milesDriven',
                  'Miles driven',
                  const Color(0xFF5C6BC0),
                  const Color(0xFFE8EAF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEquivalentItem(
                  Icons.bolt,
                  monthsElectricity,
                  'Months electricity',
                  const Color(0xFFFF8F00),
                  const Color(0xFFFFF3E0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEquivalentItem(
                  Icons.park,
                  '$trees',
                  'Trees for 1 year',
                  AppColors.primaryGreen,
                  const Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEquivalentItem(
                  Icons.lunch_dining,
                  '$burgers',
                  'Beef burgers',
                  const Color(0xFFE53935),
                  const Color(0xFFFFEBEE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquivalentItem(
    IconData icon,
    String value,
    String label,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;

  _GaugePainter({required this.value, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final bgPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      bgPaint,
    );

    final valuePaint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = maxValue > 0 ? (value / maxValue) * 2 * pi : 0.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.maxValue != maxValue;
  }
}
