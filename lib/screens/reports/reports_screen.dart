import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/app_bottom_nav.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
                'Reports',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // Monthly summary card
              _buildSummaryCard(
                title: 'This Month',
                flights: 3,
                emissions: 0.84,
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                title: 'This Year',
                flights: 12,
                emissions: 2.4,
                icon: Icons.date_range,
              ),
              const SizedBox(height: 24),
              // Placeholder for charts
              Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 48, color: Color(0xFFBDBDBD)),
                    SizedBox(height: 12),
                    Text(
                      'Monthly Emissions Chart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Coming soon',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  '$flights flights',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${emissions}t',
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
}
