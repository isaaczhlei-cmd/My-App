import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/add_flight/add_flight_screen.dart';
import '../screens/compare/compare_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/profile/profile_screen.dart';

/// Shared bottom navigation bar used by all screens except HomeScreen.
/// HomeScreen has its own bottom nav (Isaac is building it).
///
/// Usage: AppBottomNav(currentIndex: 1)  // for the Add tab
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.cardBackground,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: AppColors.textSecondary,
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;

        final Widget screen = switch (index) {
          0 => const HomeScreen(),
          1 => const AddFlightScreen(),
          2 => const CompareScreen(),
          3 => const ReportsScreen(),
          4 => ProfileScreen(),
          _ => const HomeScreen(),
        };

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => screen,
            transitionDuration: Duration.zero,
          ),
        );
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: 'Add',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.compare_arrows),
          label: 'Compare',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}
