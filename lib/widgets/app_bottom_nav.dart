import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/add_flight/add_flight_screen.dart';
import '../screens/compare/compare_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/book_flight/book_flight_screen.dart';

/// Shared bottom navigation bar used across all main screens.
/// Profile is accessed via the header icon button on the Home screen.
///
/// Tabs: Home(0)  Add(1)  Compare(2)  Reports(3)  Book(4)
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;

        final Widget screen = switch (index) {
          0 => const HomeScreen(),
          1 => const AddFlightScreen(),
          2 => const CompareScreen(),
          3 => const ReportsScreen(),
          4 => const BookFlightScreen(),
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
          icon: Icon(Icons.airplane_ticket),
          label: 'Book',
        ),
      ],
    );
  }
}
