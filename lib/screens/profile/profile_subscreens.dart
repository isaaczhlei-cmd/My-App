import 'package:flutter/material.dart';
import '../../config/theme.dart';

class FlightHistoryScreen extends StatelessWidget {
  const FlightHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Flight History'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your saved flights will appear here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Notification preferences can be configured here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'App settings will appear here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flight Carbon Tracker',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Track your flights and estimate CO₂ impact to fly more consciously.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
