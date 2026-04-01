import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

/// Shown when a guest taps a profile menu item. Includes a **Sign In** tab
/// and a button that signs out the anonymous session so the app root shows
/// the full sign-in / registration flow.
class GuestSignInPromptScreen extends StatelessWidget {
  const GuestSignInPromptScreen({super.key, required this.featureLabel});

  final String featureLabel;

  Future<void> _onSignIn(BuildContext context) async {
    // End the anonymous session, then reveal the root auth gate so it can
    // show the login/signup screen without removing the app's auth wrapper.
    await AuthService().signOut();
    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Profile'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryGreen,
              tabs: const [
                Tab(text: 'Sign In'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in to use $featureLabel',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Create an account or sign in with Google or email to unlock this feature and sync your data.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _onSignIn(context),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Not now'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
