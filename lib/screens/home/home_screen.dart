import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/eco_tip_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_inbox_service.dart';
import '../../services/user_preferences_service.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import 'widgets/flight_card.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/notification_badge.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _recentFlightsLimit = 4;
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _ecoTipService = EcoTipService();
  final _notificationInbox = NotificationInboxService.instance;
  final Set<String> _queuedEcoTipDeliveryKeys = <String>{};
  bool _isSendingVerification = false;
  bool _isRefreshingVerification = false;

  bool _isInCurrentMonth(DateTime date, DateTime now) {
    return date.year == now.year && date.month == now.month;
  }

  final Map<String, Timer> _pendingDeletions = {};
  final Map<String, Flight> _pendingFlightData = {};

  @override
  void initState() {
    super.initState();
    _notificationInbox.load();
  }

  @override
  void dispose() {
    for (final entry in _pendingDeletions.entries) {
      entry.value.cancel();
      _firestoreService.deleteFlight(entry.key);
    }
    _pendingDeletions.clear();
    _pendingFlightData.clear();
    _ecoTipService.dispose();
    super.dispose();
  }

  void _handleFlightDismiss(Flight flight) {
    final flightId = flight.id;
    setState(() {
      _pendingFlightData[flightId] = flight;
      _pendingDeletions[flightId] = Timer(const Duration(seconds: 5), () {
        _firestoreService.deleteFlight(flightId);
        if (mounted) {
          setState(() {
            _pendingDeletions.remove(flightId);
            _pendingFlightData.remove(flightId);
          });
        }
      });
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Flight deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _pendingDeletions[flightId]?.cancel();
            setState(() {
              _pendingDeletions.remove(flightId);
              _pendingFlightData.remove(flightId);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            final hasFlightLogWarning = snapshot.hasError;
            final flights = [...(snapshot.data ?? <Flight>[])]
              ..sort((a, b) => b.date.compareTo(a.date));
            final now = DateTime.now();
            final currentMonthFlights = flights
                .where((flight) => _isInCurrentMonth(flight.date, now))
                .toList();

            // Calculate real stats from flight data
            final totalFlights = flights.length;
            final totalEmissionsKg = flights.fold<double>(
              0,
              (sum, f) => sum + f.emissionsKg,
            );
            final totalCO2Tons = totalEmissionsKg / 1000;
            final avgKgPerFlight = totalFlights > 0
                ? (totalEmissionsKg / totalFlights).round()
                : 0;
            // Rough estimate: 1 kg CO2 ≈ 2.51 miles; convert to km if needed
            final distKm =
                UserPreferencesService.instance.distanceUnit == DistanceUnit.km;
            final totalDistK = distKm
                ? (totalEmissionsKg * 2.51 * 1.60934 / 1000)
                : (totalEmissionsKg * 2.51 / 1000);
            final totalMilesK =
                totalDistK; // variable kept for call-site compat

            final recentFlights = currentMonthFlights
                .take(_recentFlightsLimit)
                .toList();
            final recentTravelPattern = _buildRecentTravelPattern(
              recentFlights,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _queueEcoTipNotification(
                flightCount: totalFlights,
                totalEmissionsKg: totalEmissionsKg,
                recentTravelPattern: recentTravelPattern,
              );
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildEmailVerificationBanner(),
                  if (hasFlightLogWarning) ...[
                    const SizedBox(height: 12),
                    _buildFlightLogWarning(),
                  ],
                  const SizedBox(height: 24),
                  _buildFootprintCard(totalCO2Tons),
                  const SizedBox(height: 20),
                  _buildStatsRow(
                    context,
                    totalFlights,
                    totalMilesK,
                    avgKgPerFlight,
                  ),
                  const SizedBox(height: 20),
                  _buildJourneyMapCard(flights),
                  const SizedBox(height: 20),
                  _buildMonthlyTrends(flights),
                  const SizedBox(height: 20),
                  _buildImpactStories(
                    flights: flights,
                    totalEmissionsKg: totalEmissionsKg,
                    avgKgPerFlight: avgKgPerFlight,
                  ),
                  const SizedBox(height: 24),
                  _buildRecentFlights(recentFlights),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildFlightLogWarning() {
    final themeColors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warningOrange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.warningOrange.withValues(alpha: 0.95),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Flight log sync is unavailable right now.',
              style: TextStyle(
                color: themeColors.onCard,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _queueEcoTipNotification({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
  }) {
    if (!UserPreferencesService.instance.ecoTipsEnabled) return;

    final now = DateTime.now();
    final deliveryKey =
        'eco-tip-${now.year}-${now.month}-${now.day}|$flightCount|${totalEmissionsKg.toStringAsFixed(1)}|$recentTravelPattern';

    if (!_queuedEcoTipDeliveryKeys.add(deliveryKey)) return;
    if (_queuedEcoTipDeliveryKeys.length > 20) {
      _queuedEcoTipDeliveryKeys.remove(_queuedEcoTipDeliveryKeys.first);
    }

    _ecoTipService
        .fetchEcoTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
        )
        .then((tip) {
          if (!mounted) return;
          _notificationInbox.addMissedEcoTip(
            deliveryKey: deliveryKey,
            tip: tip,
          );
        })
        .catchError((Object _) {});
  }

  String _welcomeGreeting() {
    if (_authService.isGuest) {
      return 'Welcome User';
    }
    final user = _authService.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'Welcome $name';
    }
    final email = user?.email;
    if (email != null && email.isNotEmpty) {
      final local = email.split('@').first;
      if (local.isNotEmpty) {
        return 'Welcome $local';
      }
    }
    return 'Welcome User';
  }

  Widget _buildHeader() {
    final themeColors = context.appColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _welcomeGreeting(),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: themeColors.onCard,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                'Dashboard',
                style: TextStyle(fontSize: 16, color: themeColors.onCardMuted),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _notificationInbox,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ),
                // Show total notifications count on the avatar corner.
                // We use `notifications.length` (total stored notifications)
                // rather than `unreadCount` because the Notifications screen
                // marks items read on open — the user expects the red dot
                // to reflect that there are (total) notifications available.
                if (_notificationInbox.notifications.isNotEmpty)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: NotificationBadge(
                      count: _notificationInbox.notifications.length,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmailVerificationBanner() {
    final themeColors = context.appColors;

    return StreamBuilder<User?>(
      stream: _authService.userChanges,
      initialData: _authService.currentUser,
      builder: (context, snapshot) {
        final user = _authService.currentUser ?? snapshot.data;
        final shouldVerify =
            user != null &&
            !user.isAnonymous &&
            user.email != null &&
            !user.emailVerified;

        if (!shouldVerify) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warningOrange.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.warningOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verify your email',
                        style: TextStyle(
                          color: themeColors.onCard,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Check ${user.email} for the verification link.',
                  style: TextStyle(
                    color: themeColors.onCardMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSendingVerification
                          ? null
                          : _sendVerificationEmail,
                      icon: _isSendingVerification
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mail_outline, size: 18),
                      label: const Text('Resend email'),
                    ),
                    TextButton.icon(
                      onPressed: _isRefreshingVerification
                          ? null
                          : _refreshVerificationStatus,
                      icon: _isRefreshingVerification
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text('I verified'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSendingVerification = true;
    });

    final result = await _authService.sendEmailVerification();

    if (!mounted) return;
    setState(() {
      _isSendingVerification = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Verification email sent')),
    );
  }

  Future<void> _refreshVerificationStatus() async {
    setState(() {
      _isRefreshingVerification = true;
    });

    final result = await _authService.reloadCurrentUser();

    if (!mounted) return;
    setState(() {
      _isRefreshingVerification = false;
    });

    final user = _authService.currentUser;
    final message =
        result.error ??
        (user?.emailVerified == true
            ? 'Email verified'
            : 'Email is not verified yet');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFootprintCard(double totalCO2Tons) {
    return ListenableBuilder(
      listenable: UserPreferencesService.instance,
      builder: (context, _) {
        final prefs = UserPreferencesService.instance;
        final goalTons = prefs.annualCo2GoalTons;
        final co2Unit = prefs.co2Unit;

        // Format display value respecting unit setting
        final String displayValue;
        final String displayUnit;
        if (co2Unit == Co2Unit.kg) {
          displayValue = (totalCO2Tons * 1000).toStringAsFixed(0);
          displayUnit = 'kg CO';
        } else {
          displayValue = totalCO2Tons.toStringAsFixed(1);
          displayUnit = 'tons CO';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.fixedSuccessGreenFor(
                  Theme.of(context).brightness,
                ).withAlpha(177),
                AppTheme.fixedSuccessGreenFor(Theme.of(context).brightness),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${DateTime.now().year} Carbon Footprint',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: displayValue,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: '  $displayUnit',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    const TextSpan(
                      text: '2',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontFeatures: [FontFeature.subscripts()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (goalTons == null) ...[
                // No goal: original badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        totalCO2Tons == 0
                            ? 'Start tracking your flights!'
                            : 'Track & reduce your impact',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Goal set: progress bar
                _buildGoalProgress(
                  context: context,
                  currentTons: totalCO2Tons,
                  goalTons: goalTons,
                  co2Unit: co2Unit,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalProgress({
    required BuildContext context,
    required double currentTons,
    required double goalTons,
    required Co2Unit co2Unit,
  }) {
    final isOver = currentTons >= goalTons;
    final progress = goalTons > 0
        ? (currentTons / goalTons).clamp(0.0, 1.0)
        : 0.0;
    final barColor = isOver ? AppColors.errorRed : Colors.white;

    String fmt(double tons) {
      if (co2Unit == Co2Unit.kg) {
        return '${(tons * 1000).toStringAsFixed(0)} kg';
      }
      return '${tons.toStringAsFixed(1)} t';
    }

    final statusText = isOver
        ? '${fmt(currentTons - goalTons)} over goal'
        : '${fmt(goalTons - currentTons)} remaining';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${fmt(currentTons)} / ${fmt(goalTons)}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: isOver ? AppColors.errorRed : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    int totalFlights,
    double totalMilesK,
    int avgKgPerFlight,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.flight,
            iconColor: const Color(0xFF5C6BC0),
            iconBgColor: const Color(0xFFE8EAF6),
            value: '$totalFlights',
            label: 'Flights',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.route,
            iconColor: const Color(0xFFFF8F00),
            iconBgColor: const Color(0xFFFFF3E0),
            value: '${totalMilesK.toStringAsFixed(1)}K',
            label:
                UserPreferencesService.instance.distanceUnit == DistanceUnit.km
                ? 'km'
                : 'Miles',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.speed,
            iconColor: AppTheme.fixedSuccessGreenFor(
              Theme.of(context).brightness,
            ),
            iconBgColor: const Color(0xFFE8F5E9),
            value: UserPreferencesService.instance.co2Unit == Co2Unit.kg
                ? '${avgKgPerFlight}kg'
                : '${(avgKgPerFlight / 1000).toStringAsFixed(2)}t',
            label: 'Avg/Flight',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String value,
    required String label,
  }) {
    final themeColors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: themeColors.onCard,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: themeColors.onCardMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyMapCard(List<Flight> flights) {
    final themeColors = context.appColors;
    final mappedFlights = flights.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.public,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Flight Map',
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 148,
            width: double.infinity,
            child: CustomPaint(
              painter: _JourneyMapPainter(
                flights: mappedFlights,
                accent: Theme.of(context).colorScheme.primary,
                muted: themeColors.onCardMuted,
                outline: themeColors.outlineSoft,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (mappedFlights.isEmpty)
            Text(
              'Add a flight to draw your first route.',
              style: TextStyle(color: themeColors.onCardMuted, fontSize: 14),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mappedFlights
                  .map(
                    (flight) => _RouteChip(
                      label:
                          '${flight.originCode} -> ${flight.destinationCode}',
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrends(List<Flight> flights) {
    final themeColors = context.appColors;
    final buckets = _monthlyEmissionBuckets(flights);
    final maxKg = buckets.fold<double>(
      0,
      (maxValue, point) => math.max(maxValue, point.emissionsKg),
    );
    final bestMonth = buckets
        .where((point) => point.emissionsKg > 0)
        .fold<_MonthlyEmissionPoint?>(null, (best, point) {
          if (best == null || point.emissionsKg < best.emissionsKg) {
            return point;
          }
          return best;
        });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: const Color(0xFFFF8F00), size: 20),
              const SizedBox(width: 8),
              Text(
                'Emission Trends',
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 152,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((point) {
                final ratio = maxKg == 0 ? 0.0 : point.emissionsKg / maxKg;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _MonthlyTrendBar(point: point, ratio: ratio),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            bestMonth == null
                ? 'No yearly trend yet'
                : 'Greenest month: ${bestMonth.label} at ${bestMonth.emissionsKg.round()} kg CO2.',
            style: TextStyle(color: themeColors.onCardMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStories({
    required List<Flight> flights,
    required double totalEmissionsKg,
    required int avgKgPerFlight,
  }) {
    final themeColors = context.appColors;
    final milesDriven = (totalEmissionsKg * 2.51).round();
    final homeMonths = totalEmissionsKg <= 0 ? 0.0 : totalEmissionsKg / 280;
    final efficientFlight = flights
        .where((flight) => flight.emissionsKg > 0)
        .fold<Flight?>(null, (best, flight) {
          if (best == null || flight.emissionsKg < best.emissionsKg) {
            return flight;
          }
          return best;
        });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Row(
        children: [
          _ImpactRing(totalKg: totalEmissionsKg),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carbon Story',
                  style: TextStyle(
                    color: themeColors.onCard,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalEmissionsKg == 0
                      ? 'Your next logged trip will unlock impact milestones.'
                      : 'Equivalent to driving ${_formatInt(milesDriven)} miles or powering a home for ${homeMonths.toStringAsFixed(1)} months.',
                  style: TextStyle(
                    color: themeColors.onCardMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _MilestonePill(
                  icon: Icons.bolt_outlined,
                  label: efficientFlight == null
                      ? 'Most efficient trip awaits'
                      : 'Most efficient: ${efficientFlight.originCode} -> ${efficientFlight.destinationCode}',
                ),
                const SizedBox(height: 8),
                _MilestonePill(
                  icon: Icons.speed,
                  label: avgKgPerFlight == 0
                      ? 'Average unlocks after logging'
                      : 'Average: ${_formatInt(avgKgPerFlight)} kg per flight',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_MonthlyEmissionPoint> _monthlyEmissionBuckets(List<Flight> flights) {
    final now = DateTime.now();
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      final kg = flights
          .where(
            (flight) =>
                flight.date.year == month.year &&
                flight.date.month == month.month,
          )
          .fold<double>(0, (sum, flight) => sum + flight.emissionsKg);
      return _MonthlyEmissionPoint(
        label: monthNames[month.month - 1],
        emissionsKg: kg,
      );
    });
  }

  String _formatInt(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  Widget _buildRecentFlights(List<Flight> recentFlights) {
    final themeColors = context.appColors;
    final visibleFlights = recentFlights
        .where((f) => !_pendingDeletions.containsKey(f.id))
        .toList();
    final isGuest = _authService.isGuest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Flights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: themeColors.onCard,
          ),
        ),
        const SizedBox(height: 8),
        if (visibleFlights.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeColors.outlineSoft),
            ),
            child: Column(
              children: [
                Icon(Icons.flight_takeoff, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No flights this month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeColors.onCard,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a flight dated this month to start tracking',
                  style: TextStyle(
                    fontSize: 14,
                    color: themeColors.onCardMuted,
                  ),
                ),
              ],
            ),
          )
        else
          ...visibleFlights.map((flight) {
            if (isGuest) return FlightCard(flight: flight, compact: true);
            return Dismissible(
              key: Key(flight.id),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => _handleFlightDismiss(flight),
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: FlightCard(flight: flight, compact: true),
            );
          }),
      ],
    );
  }

  String _buildRecentTravelPattern(List<Flight> recentFlights) {
    if (recentFlights.isEmpty) {
      return 'No recorded flights yet.';
    }

    final routes = recentFlights
        .take(3)
        .map((flight) => '${flight.originCode} -> ${flight.destinationCode}')
        .join(', ');
    return 'Recent routes: $routes.';
  }
}

class _MonthlyEmissionPoint {
  const _MonthlyEmissionPoint({required this.label, required this.emissionsKg});

  final String label;
  final double emissionsKg;
}

class _MonthlyTrendBar extends StatelessWidget {
  const _MonthlyTrendBar({required this.point, required this.ratio});

  final _MonthlyEmissionPoint point;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final barHeight = 18.0 + (ratio * 82.0);
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          point.emissionsKg == 0 ? '-' : point.emissionsKg.round().toString(),
          style: TextStyle(color: themeColors.onCardMuted, fontSize: 11),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          height: barHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: point.emissionsKg == 0
                ? themeColors.cardMuted
                : Color.lerp(accent, const Color(0xFFFF8F00), ratio * 0.55),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          point.label,
          style: TextStyle(
            color: themeColors.onCardMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: themeColors.onCard,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImpactRing extends StatelessWidget {
  const _ImpactRing({required this.totalKg});

  final double totalKg;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final progress = (totalKg / 2000).clamp(0.0, 1.0);
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _ImpactRingPainter(
          progress: progress,
          accent: Theme.of(context).colorScheme.primary,
          track: themeColors.cardMuted,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalKg < 1000
                    ? totalKg.round().toString()
                    : (totalKg / 1000).toStringAsFixed(1),
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                totalKg < 1000 ? 'kg' : 'tons',
                style: TextStyle(color: themeColors.onCardMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestonePill extends StatelessWidget {
  const _MilestonePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: themeColors.onCard,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImpactRingPainter extends CustomPainter {
  const _ImpactRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 8.0;
    final rect = Offset.zero & size;
    final circleRect = rect.deflate(strokeWidth / 2);
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [accent, const Color(0xFFFF8F00), accent],
      ).createShader(circleRect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(circleRect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      circleRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ImpactRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        accent != oldDelegate.accent ||
        track != oldDelegate.track;
  }
}

class _JourneyMapPainter extends CustomPainter {
  const _JourneyMapPainter({
    required this.flights,
    required this.accent,
    required this.muted,
    required this.outline,
  });

  final List<Flight> flights;
  final Color accent;
  final Color muted;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()
      ..color = outline.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final routePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final routeShadowPaint = Paint()
      ..color = accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    _drawWorldHint(canvas, size, landPaint);

    if (flights.isEmpty) {
      final emptyPaint = Paint()
        ..color = muted.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.65),
        Offset(size.width * 0.82, size.height * 0.38),
        emptyPaint,
      );
      return;
    }

    for (var i = 0; i < flights.length; i++) {
      final start = _pointForCode(flights[i].originCode, size);
      final end = _pointForCode(flights[i].destinationCode, size);
      final control = Offset(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) - 26 - (i % 2) * 8,
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, routeShadowPaint);
      canvas.drawPath(path, routePaint);
      _drawDot(canvas, start, muted);
      _drawDot(canvas, end, accent);
    }
  }

  void _drawWorldHint(Canvas canvas, Size size, Paint paint) {
    final americas = Rect.fromLTWH(
      size.width * 0.07,
      size.height * 0.20,
      size.width * 0.25,
      size.height * 0.46,
    );
    final europeAfrica = Rect.fromLTWH(
      size.width * 0.42,
      size.height * 0.18,
      size.width * 0.20,
      size.height * 0.50,
    );
    final asia = Rect.fromLTWH(
      size.width * 0.62,
      size.height * 0.22,
      size.width * 0.30,
      size.height * 0.38,
    );

    canvas.drawOval(americas, paint);
    canvas.drawOval(europeAfrica, paint);
    canvas.drawOval(asia, paint);
    canvas.drawLine(
      Offset(size.width * 0.03, size.height * 0.74),
      Offset(size.width * 0.97, size.height * 0.74),
      paint,
    );
  }

  void _drawDot(Canvas canvas, Offset offset, Color color) {
    final paint = Paint()..color = color;
    final halo = Paint()..color = color.withValues(alpha: 0.18);
    canvas.drawCircle(offset, 7, halo);
    canvas.drawCircle(offset, 3.5, paint);
  }

  Offset _pointForCode(String code, Size size) {
    final hash = code.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final normalized = code.toUpperCase();
    final known = <String, Offset>{
      'LAX': const Offset(0.16, 0.50),
      'SFO': const Offset(0.15, 0.42),
      'SEA': const Offset(0.15, 0.31),
      'JFK': const Offset(0.29, 0.43),
      'EWR': const Offset(0.29, 0.44),
      'ATL': const Offset(0.25, 0.54),
      'ORD': const Offset(0.23, 0.40),
      'DFW': const Offset(0.20, 0.56),
      'HND': const Offset(0.79, 0.47),
      'NRT': const Offset(0.80, 0.45),
      'SIN': const Offset(0.72, 0.68),
      'LHR': const Offset(0.48, 0.36),
      'CDG': const Offset(0.50, 0.39),
      'DXB': const Offset(0.58, 0.54),
      'SYD': const Offset(0.84, 0.78),
    }[normalized];
    final fallback = Offset(0.12 + (hash % 73) / 100, 0.28 + (hash % 41) / 100);
    final unit = known ?? fallback;
    return Offset(unit.dx * size.width, unit.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _JourneyMapPainter oldDelegate) {
    return flights != oldDelegate.flights ||
        accent != oldDelegate.accent ||
        muted != oldDelegate.muted ||
        outline != oldDelegate.outline;
  }
}
