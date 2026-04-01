import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_bottom_nav.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            final flights = snapshot.data ?? [];

            // Calculate this month's stats
            final now = DateTime.now();
            final thisMonthFlights = flights.where((f) =>
                f.date.year == now.year && f.date.month == now.month).toList();
            final thisMonthKg = thisMonthFlights.fold<double>(0, (s, f) => s + f.emissionsKg);

            // Calculate this year's stats
            final thisYearFlights = flights.where((f) => f.date.year == now.year).toList();
            final thisYearKg = thisYearFlights.fold<double>(0, (s, f) => s + f.emissionsKg);

            // Build monthly breakdown for chart (last 6 months)
            final monthlyData = <_MonthData>[];
            for (int i = 5; i >= 0; i--) {
              final month = DateTime(now.year, now.month - i, 1);
              final monthFlights = flights.where((f) =>
                  f.date.year == month.year && f.date.month == month.month).toList();
              final monthKg = monthFlights.fold<double>(0, (s, f) => s + f.emissionsKg);
              monthlyData.add(_MonthData(
                label: DateFormat('MMM').format(month),
                emissionsKg: monthKg,
                flightCount: monthFlights.length,
              ));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryCard(
                    title: 'This Month',
                    flights: thisMonthFlights.length,
                    emissions: thisMonthKg / 1000,
                    icon: Icons.calendar_today,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    title: 'This Year',
                    flights: thisYearFlights.length,
                    emissions: thisYearKg / 1000,
                    icon: Icons.date_range,
                  ),
                  const SizedBox(height: 24),
                  _buildMonthlyChart(monthlyData),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int flights,
    required double emissions,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$flights flight${flights == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${emissions.toStringAsFixed(2)}t',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Text(
                'CO\u2082',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(List<_MonthData> monthlyData) {
    final maxKg = monthlyData.fold<double>(0, (m, d) => d.emissionsKg > m ? d.emissionsKg : m);
    final hasData = maxKg > 0;

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
            'Monthly Emissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          if (!hasData)
            SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Add flights to see your monthly breakdown',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: monthlyData.map((data) {
                  final barHeight = maxKg > 0 ? (data.emissionsKg / maxKg) * 120 : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (data.emissionsKg > 0)
                            Text(
                              '${(data.emissionsKg / 1000).toStringAsFixed(1)}t',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: barHeight.clamp(4.0, 120.0),
                            decoration: BoxDecoration(
                              color: data.emissionsKg > 0
                                  ? AppColors.primaryGreen
                                  : const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthData {
  final String label;
  final double emissionsKg;
  final int flightCount;

  _MonthData({
    required this.label,
    required this.emissionsKg,
    required this.flightCount,
  });
}
