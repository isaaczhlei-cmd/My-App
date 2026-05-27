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
                .where((flight) => flight.date.year == now.year)
                .toList();
            final totalKg = flights.fold<double>(
              0,
              (sum, flight) => sum + flight.emissionsKg,
            );
            final averageKg = flights.isEmpty ? 0 : totalKg / flights.length;
            final bestFlight = _lowestEmissionFlight(flights);
            final heaviestRoute = _heaviestRoute(flights);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compare',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'See where your flights land and what to improve next.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAnnualSnapshot(
                    flightCount: flights.length,
                    totalKg: totalKg,
                    averageKg: averageKg.toDouble(),
                  ),
                  const SizedBox(height: 14),
                  _buildRouteInsightCard(bestFlight, heaviestRoute),
                  const SizedBox(height: 14),
                  _buildDecisionCard(),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Flight? _lowestEmissionFlight(List<Flight> flights) {
    if (flights.isEmpty) return null;
    final sorted = [...flights]
      ..sort((a, b) => a.emissionsKg.compareTo(b.emissionsKg));
    return sorted.first;
  }

  _RouteSummary? _heaviestRoute(List<Flight> flights) {
    if (flights.isEmpty) return null;
    final routes = <String, _RouteSummary>{};

    for (final flight in flights) {
      final key = '${flight.originCode}->${flight.destinationCode}';
      final route = routes[key];
      routes[key] = route == null
          ? _RouteSummary(
              label: '${flight.originCode} -> ${flight.destinationCode}',
              count: 1,
              emissionsKg: flight.emissionsKg,
            )
          : route.copyWith(
              count: route.count + 1,
              emissionsKg: route.emissionsKg + flight.emissionsKg,
            );
    }

    final sorted = routes.values.toList()
      ..sort((a, b) => b.emissionsKg.compareTo(a.emissionsKg));
    return sorted.first;
  }

  Widget _buildAnnualSnapshot({
    required int flightCount,
    required double totalKg,
    required double averageKg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Year',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  '${(totalKg / 1000).toStringAsFixed(2)}t',
                  'Total CO\u2082',
                  AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  '$flightCount',
                  'Flights',
                  const Color(0xFF82A8FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  '${averageKg.round()}kg',
                  'Avg / flight',
                  AppColors.warningOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRouteInsightCard(Flight? bestFlight, _RouteSummary? route) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Insights',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (bestFlight == null || route == null)
            const Text(
              'Add flights to compare your cleanest flight and highest-emission route.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            )
          else ...[
            _buildInsightRow(
              Icons.eco_outlined,
              'Cleanest logged flight',
              '${bestFlight.originCode} -> ${bestFlight.destinationCode} • ${bestFlight.emissionsKg.round()}kg CO\u2082',
              AppColors.primaryGreen,
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              Icons.trending_up,
              'Highest-emission route',
              '${route.label} • ${(route.emissionsKg / 1000).toStringAsFixed(2)}t across ${route.count} flight${route.count == 1 ? '' : 's'}',
              AppColors.warningOrange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    IconData icon,
    String title,
    String detail,
    Color accent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.5),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare Before You Fly',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Use Flight Search to compare the lowest-carbon option against the cheapest option for the same route.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary {
  final String label;
  final int count;
  final double emissionsKg;

  _RouteSummary({
    required this.label,
    required this.count,
    required this.emissionsKg,
  });

  _RouteSummary copyWith({int? count, double? emissionsKg}) {
    return _RouteSummary(
      label: label,
      count: count ?? this.count,
      emissionsKg: emissionsKg ?? this.emissionsKg,
    );
  }
}
