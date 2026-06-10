import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/firestore_service.dart';
import '../../services/user_preferences_service.dart';
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
    final themeColors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            final flights = snapshot.data ?? [];

            // Calculate this month's stats
            final now = DateTime.now();
            final thisMonthFlights = flights
                .where(
                  (f) => f.date.year == now.year && f.date.month == now.month,
                )
                .toList();
            final thisMonthKg = thisMonthFlights.fold<double>(
              0,
              (s, f) => s + f.emissionsKg,
            );

            // Calculate this year's stats
            final thisYearFlights = flights
                .where((f) => f.date.year == now.year)
                .toList();
            final thisYearKg = thisYearFlights.fold<double>(
              0,
              (s, f) => s + f.emissionsKg,
            );

            // Build monthly breakdown for chart (last 6 months)
            final monthlyData = <_MonthData>[];
            for (int i = 5; i >= 0; i--) {
              final month = DateTime(now.year, now.month - i, 1);
              final monthFlights = flights
                  .where(
                    (f) =>
                        f.date.year == month.year &&
                        f.date.month == month.month,
                  )
                  .toList();
              final monthKg = monthFlights.fold<double>(
                0,
                (s, f) => s + f.emissionsKg,
              );
              monthlyData.add(
                _MonthData(
                  label: DateFormat('MMM').format(month),
                  emissionsKg: monthKg,
                  flightCount: monthFlights.length,
                ),
              );
            }
            final topRoutes = _topRoutes(flights);

            // Add bottom padding equal to the bottom nav height and
            // any system bottom inset so content isn't overlapped.
            final bottomInset = MediaQuery.of(context).padding.bottom;
            final scrollBottom =
                20.0 + kBottomNavigationBarHeight + bottomInset + 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, scrollBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: themeColors.onCard,
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
                  const SizedBox(height: 24),
                  _buildTopRoutesCard(topRoutes),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  List<_RouteData> _topRoutes(List<Flight> flights) {
    final routes = <String, _RouteData>{};

    for (final flight in flights) {
      final originCode = flight.originCode.trim().toUpperCase();
      final destinationCode = flight.destinationCode.trim().toUpperCase();
      final key = '$originCode->$destinationCode';
      final existing = routes[key];

      if (existing == null) {
        routes[key] = _RouteData(
          originCode: originCode,
          destinationCode: destinationCode,
          flightCount: 1,
          emissionsKg: flight.emissionsKg,
        );
      } else {
        routes[key] = existing.copyWith(
          flightCount: existing.flightCount + 1,
          emissionsKg: existing.emissionsKg + flight.emissionsKg,
        );
      }
    }

    final sortedRoutes = routes.values.toList()
      ..sort((a, b) => b.emissionsKg.compareTo(a.emissionsKg));

    return sortedRoutes.take(3).toList();
  }

  Widget _buildSummaryCard({
    required String title,
    required int flights,
    required double emissions,
    required IconData icon,
  }) {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeColors.onCard,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$flights flight${flights == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeColors.onCardMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                UserPreferencesService.instance.co2Unit == Co2Unit.kg
                    ? '${(emissions * 1000).toStringAsFixed(0)} kg'
                    : '${emissions.toStringAsFixed(2)}t',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeColors.onCard,
                ),
              ),
              Text(
                'CO\u2082',
                style: TextStyle(fontSize: 12, color: themeColors.onCardMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopRoutesCard(List<_RouteData> routes) {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Routes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeColors.onCard,
            ),
          ),
          const SizedBox(height: 16),
          if (routes.isEmpty)
            Text(
              'Add flights to see your top routes.',
              style: TextStyle(fontSize: 14, color: themeColors.onCardMuted),
            )
          else
            ...routes.indexed.map((entry) {
              final index = entry.$1;
              final route = entry.$2;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == routes.length - 1 ? 0 : 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: themeColors.onCard,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${route.originCode} -> ${route.destinationCode}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: themeColors.onCard,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${route.flightCount} flight${route.flightCount == 1 ? '' : 's'} • ${(route.emissionsKg / 1000).toStringAsFixed(2)}t CO\u2082',
                            style: TextStyle(
                              fontSize: 13,
                              color: themeColors.onCardMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(List<_MonthData> monthlyData) {
    final themeColors = context.appColors;
    final maxKg = monthlyData.fold<double>(
      0,
      (m, d) => d.emissionsKg > m ? d.emissionsKg : m,
    );
    final hasData = maxKg > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Emissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeColors.onCard,
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
                      style: TextStyle(
                        fontSize: 14,
                        color: themeColors.onCardMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 168,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: monthlyData.map((data) {
                  final barHeight = maxKg > 0
                      ? (data.emissionsKg / maxKg) * 120
                      : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (data.emissionsKg > 0)
                            Text(
                              '${(data.emissionsKg / 1000).toStringAsFixed(1)}t',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: themeColors.onCard,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: barHeight.clamp(4.0, 120.0),
                            decoration: BoxDecoration(
                              color: data.emissionsKg > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : themeColors.cardMuted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: themeColors.onCardMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data.flightCount} flight${data.flightCount == 1 ? '' : 's'}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: themeColors.onCardMuted,
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

class _RouteData {
  final String originCode;
  final String destinationCode;
  final int flightCount;
  final double emissionsKg;

  _RouteData({
    required this.originCode,
    required this.destinationCode,
    required this.flightCount,
    required this.emissionsKg,
  });

  _RouteData copyWith({int? flightCount, double? emissionsKg}) {
    return _RouteData(
      originCode: originCode,
      destinationCode: destinationCode,
      flightCount: flightCount ?? this.flightCount,
      emissionsKg: emissionsKg ?? this.emissionsKg,
    );
  }
}
