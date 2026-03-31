import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import 'widgets/flight_card.dart';
import '../../widgets/app_bottom_nav.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();

  // ──────────────────────────────────────────────────────────
  // MOCK DATA — TODO: Replace with Firestore data later
  // ──────────────────────────────────────────────────────────
  final double totalco2tons = 2.4;
  final int totalflights = 12;
  final double totalmilestraveled = 28.5;
  final int avgKgPerFlight = 200;

  // Mock flight list using the Flight model from lib/models/flight.dart
  // Each Flight needs: id, originCode, destinationCode, date, travelClass,
  //                    emissionsKg, createdAt, AirlineCode, AirlineNumber
  final List<Flight> _mockFlights = [
    Flight(
      id: '1',
      originCode: 'SFO',
      destinationCode: 'JFK',
      date: DateTime(2024, 11, 15),
      travelClass: 'economy',
      emissionsKg: 520,
      createdAt: DateTime.now(),
      AirlineCode: 'UA',
      AirlineNumber: '123',
    ),
    Flight(
      id: '2',
      originCode: 'LAX',
      destinationCode: 'ORD',
      date: DateTime(2024, 11, 8),
      travelClass: 'business',
      emissionsKg: 380,
      createdAt: DateTime.now(),
      AirlineCode: 'DL',
      AirlineNumber: '456',
    ),
  ];

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
              buildheader(),
              const SizedBox(height: 24),
              buildfootprintcard(),
              const SizedBox(height: 20),
              buildstatsrow(),
              const SizedBox(height: 24),
              buildrecentflights(),
              const SizedBox(height: 20),
              buildecotip(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Header — welcome uses guest vs account name
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

  Widget buildheader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _welcomeGreeting(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.person, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ✅ DONE — Carbon Footprint Card (Isaac built this!)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildfootprintcard() {
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
                  text: '$totalco2tons',
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '18% vs last year',
                  style: TextStyle(
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Stats row — Flights, Miles, Avg / flight
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildstatsrow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.flight,
            iconColor: const Color(0xFF5C6BC0),
            iconBgColor: const Color(0xFFE8EAF6),
            value: '$totalflights',
            label: 'Flights',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.route,
            iconColor: const Color(0xFFFF8F00),
            iconBgColor: const Color(0xFFFFF3E0),
            value: '${totalmilestraveled}K',
            label: 'Miles',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            icon: Icons.speed,
            iconColor: AppColors.primaryGreen,
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Recent flights
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildrecentflights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Flights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._mockFlights.map((flight) => FlightCard(flight: flight)),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Eco tip
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildecotip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.eco,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eco Tip',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Direct flights produce 20% less CO\u2082 than connecting flights.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
