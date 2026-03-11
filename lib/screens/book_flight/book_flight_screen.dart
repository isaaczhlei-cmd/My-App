import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../widgets/app_bottom_nav.dart';

class BookFlightScreen extends StatelessWidget{
  const BookFlightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(bottomNavigationBar: const AppBottomNav(currentIndex: 4));
  }
}
