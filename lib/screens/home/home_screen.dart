import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../models/flight.dart';
import 'widgets/flight_card.dart';
import '../../widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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

              // =============================================
              // TODO Step 1: Build the Stats Row
              // =============================================
              // Call buildstatsrow() here
              // const SizedBox(height: 24),
              buildstatsrow(),
              const SizedBox(height: 24),

              // =============================================
              // TODO Step 2: Build the Recent Flights Section
              // =============================================
              // Call buildrecentflights() here
              buildrecentflights(),
              const SizedBox(height: 20),

              // =============================================
              // TODO Step 3: Build the Eco Tip Card
              // =============================================
              // Call buildecotip() here
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
  // ✅ DONE — Header (Isaac built this!)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildheader() {
    final displayName = _authService.currentUser?.displayName ?? 'Isaac';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              "$displayName's Dashboard",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
              // TODO: Navigate to profile
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TODO Step 1: STATS ROW
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Goal: A Row of 3 stat boxes (Flights, Miles, Avg/Flight)
  //
  // Layout structure:
  //   Row(
  //     children: [
  //       Expanded(child: _buildStatItem(...)),  // Flights
  //       SizedBox(width: 12),
  //       Expanded(child: _buildStatItem(...)),  // Miles
  //       SizedBox(width: 12),
  //       Expanded(child: _buildStatItem(...)),  // Avg/Flight
  //     ],
  //   )
  //
  // Each stat box should be a white Container with rounded corners (14),
  // containing a Column with:
  //   1. A colored icon inside a rounded square (40x40 Container)
  //   2. The stat value (bold, fontSize: 22, color: Color(0xFF1A1A2E))
  //   3. The label (fontSize: 12, color: Color(0xFF9E9E9E))
  //
  // Stat details:
  //   - Flights: icon=Icons.flight, iconColor=Color(0xFF5C6BC0),
  //             bgColor=Color(0xFFE8EAF6), value='$totalflights'
  //   - Miles:   icon=Icons.route, iconColor=Color(0xFFFF8F00),
  //             bgColor=Color(0xFFFFF3E0), value='${totalmilestraveled}K'
  //   - Avg:     icon=Icons.speed, iconColor=AppColors.primaryGreen,
  //             bgColor=Color(0xFFE8F5E9), value='${avgKgPerFlight}kg'
  //
  // HINT: Make a helper method _buildStatItem({icon, iconColor, iconBgColor, value, label})
  //       so you don't repeat the same Container code 3 times!
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildstatsrow() {
    // TODO: Replace this placeholder with the real stats row
    return const SizedBox.shrink();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TODO Step 2: RECENT FLIGHTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Goal: Show "Recent Flights" header with "See All" button,
  //       then a list of FlightCard widgets using _mockFlights
  //
  // Layout structure:
  //   Column(
  //     children: [
  //       Row(                                    // header row
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text('Recent Flights',              // bold, 18, white)
  //           TextButton('See All',               // AppColors.primaryGreen)
  //         ],
  //       ),
  //       SizedBox(height: 8),
  //       // Loop through _mockFlights and create a FlightCard for each:
  //       ..._mockFlights.map((flight) => FlightCard(flight: flight)),
  //     ],
  //   )
  //
  // The FlightCard widget is already built for you!
  // It's imported from 'widgets/flight_card.dart'
  // Just pass it a Flight object: FlightCard(flight: myFlight)
  //
  // HINT: The "..." before _mockFlights.map() is the spread operator —
  //       it takes a list and inserts each item into the parent list.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildrecentflights() {
    // TODO: Replace this placeholder with the recent flights section
    return const SizedBox.shrink();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TODO Step 3: ECO TIP CARD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Goal: A white card with a green leaf icon and eco tip text
  //
  // Layout structure:
  //   Container(
  //     color: Colors.white, borderRadius: 14,
  //     padding: EdgeInsets.all(16),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Container(                            // green circle icon
  //           width: 40, height: 40,
  //           decoration: BoxDecoration(
  //             color: Color(0xFFE8F5E9),         // light green bg
  //             borderRadius: BorderRadius.circular(20),  // makes it a circle!
  //           ),
  //           child: Icon(Icons.eco, color: AppColors.primaryGreen, size: 20),
  //         ),
  //         SizedBox(width: 12),
  //         Expanded(                             // text column
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text('Eco Tip',                 // bold, 15, Color(0xFF1A1A2E))
  //               SizedBox(height: 4),
  //               Text('Direct flights produce 20% less CO₂ than connecting flights.',
  //                    // fontSize: 14, color: Color(0xFF757575))
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   )
  //
  // HINT: For the CO₂ subscript, you can just use the Unicode character: 'CO\u2082'
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget buildecotip() {
    // TODO: Replace this placeholder with the eco tip card
    return const SizedBox.shrink();
  }
}
