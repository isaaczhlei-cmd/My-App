import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/eco_tip_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_inbox_service.dart';
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
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            final flights = snapshot.data ?? [];
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
            // Rough estimate: 1 kg CO2 ≈ 2.51 miles flown
            final totalMilesK = (totalEmissionsKg * 2.51 / 1000);

            final recentFlights = currentMonthFlights
                .take(_recentFlightsLimit)
                .toList();
            final recentTravelPattern = _buildRecentTravelPattern(recentFlights);
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
                  const SizedBox(height: 24),
                  _buildFootprintCard(totalCO2Tons),
                  const SizedBox(height: 20),
                  _buildStatsRow(context, totalFlights, totalMilesK, avgKgPerFlight),
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

  void _queueEcoTipNotification({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
  }) {
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
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
                Positioned(
                  top: -6,
                  right: -6,
                  child: NotificationBadge(
                    count: _notificationInbox.unreadCount,
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
                const Row(
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.warningOrange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verify your email',
                        style: TextStyle(
                          color: AppColors.textPrimary,
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(177, 76, 175, 79), Color(0xFF66BB6A)],
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
              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
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
                  text: totalCO2Tons.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(
                  text: '  tons CO',
                  style: TextStyle(fontSize: 18, color: Colors.white),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        ],
      ),
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
            label: 'Miles',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.speed,
            iconColor: Theme.of(context).colorScheme.primary,
            iconBgColor: const Color(0xFFE8F5E9),
            value: '${avgKgPerFlight}kg',
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFlights(List<Flight> recentFlights) {
    final visibleFlights = recentFlights
        .where((f) => !_pendingDeletions.containsKey(f.id))
        .toList();
    final isGuest = _authService.isGuest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Flights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (visibleFlights.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.flight_takeoff, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'No flights this month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a flight dated this month to start tracking',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ...visibleFlights.map((flight) {
            if (isGuest) return FlightCard(flight: flight, compact: true);
            return Dismissible(
              key: Key(flight.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _handleFlightDismiss(flight),
              background: Container(
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
