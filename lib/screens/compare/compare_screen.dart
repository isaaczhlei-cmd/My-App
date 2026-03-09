import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/app_bottom_nav.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  // TODO: Replace with real data from flight selection
  static const double _yourEmissions = 1.18;
  static const double _avgEmissions = 1.82;
  static const int _percentBelow = 35;

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
              _buildCarbonImpactCard(),
              const SizedBox(height: 20),
              _buildEnvironmentalEquivalents(),
              const SizedBox(height: 20),
              _buildAircraftInfo(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildCarbonImpactCard() {
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
          // Gauge and stats row
          Row(
            children: [
              // Circular gauge
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _GaugePainter(
                    value: _yourEmissions,
                    maxValue: _avgEmissions * 1.3,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_yourEmissions',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
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
              // Comparison stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildComparisonRow(
                      'Your flight',
                      '${_yourEmissions}t CO\u2082',
                      AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    _buildComparisonRow(
                      'Avg. emission',
                      '${_avgEmissions}t CO\u2082',
                      const Color(0xFFFF8F00),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Below average indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_percentBelow% below average for this route',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen,
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
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E),
              ),
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

  Widget _buildEnvironmentalEquivalents() {
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
          // 2x2 grid
          Row(
            children: [
              Expanded(
                child: _buildEquivalentItem(
                  Icons.directions_car,
                  '2,960',
                  'Miles driven',
                  const Color(0xFF5C6BC0),
                  const Color(0xFFE8EAF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEquivalentItem(
                  Icons.bolt,
                  '4.2',
                  'Months of electricity',
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
                  '54',
                  'Trees for 1 year',
                  AppColors.primaryGreen,
                  const Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEquivalentItem(
                  Icons.lunch_dining,
                  '472',
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAircraftInfo() {
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
            'Aircraft Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flight,
                  color: Color(0xFF616161),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boeing 777-300ER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Fuel efficiency: 89g CO\u2082/km/pax',
                    style: TextStyle(
                      fontSize: 13,
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
}

/// Custom painter for the circular emissions gauge
class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;

  _GaugePainter({required this.value, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background track
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

    // Value arc
    final valuePaint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (value / maxValue) * 2 * pi;
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
