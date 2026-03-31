import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import 'guest_sign_in_prompt_screen.dart';
import 'profile_subscreens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  bool _uploadingPhoto = false;

  Future<void> _onAvatarTap() async {
    if (_authService.isGuest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with an account to change your profile photo'),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    final result = await _authService.updateProfilePhoto(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    if (result.success) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Update failed')),
      );
    }
  }

  void _openGuestPrompt(String featureLabel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuestSignInPromptScreen(featureLabel: featureLabel),
      ),
    );
  }

  void _pushSignedIn(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.userChanges,
      builder: (context, snapshot) {
        final user = _authService.currentUser;
        final isGuest = _authService.isGuest;
        final dn = user?.displayName?.trim();
        final displayName =
            dn != null && dn.isNotEmpty ? dn : 'Traveler';
        final email = user?.email ?? 'Guest';
        final photoUrl = user?.photoURL;

        return Scaffold(
          backgroundColor: AppColors.darkBackground,
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_circle_left),
            ),
            title: const Text('Profile'),
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _onAvatarTap,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: (!isGuest &&
                                  photoUrl != null &&
                                  photoUrl.isNotEmpty)
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                        ),
                        if (_uploadingPhoto)
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (!isGuest)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.surface),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isGuest)
                    const Text(
                      'Tap photo to change',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  // Debug auth panel: omitted in profile & release (`kDebugMode` is false).
                  if (kDebugMode) ...[
                    const SizedBox(height: 20),
                    _buildDebugPanel(user, isGuest),
                  ],
                  const SizedBox(height: 24),
                  _buildMenuItem(
                    icon: Icons.flight,
                    label: 'Flight History',
                    onTap: () {
                      if (isGuest) {
                        _openGuestPrompt('Flight History');
                      } else {
                        _pushSignedIn(const FlightHistoryScreen());
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {
                      if (isGuest) {
                        _openGuestPrompt('Notifications');
                      } else {
                        _pushSignedIn(const NotificationSettingsScreen());
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      if (isGuest) {
                        _openGuestPrompt('Settings');
                      } else {
                        _pushSignedIn(const AppSettingsScreen());
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: () {
                      if (isGuest) {
                        _openGuestPrompt('About');
                      } else {
                        _pushSignedIn(const AboutScreen());
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: isGuest
                        ? OutlinedButton.icon(
                            onPressed: () =>
                                _openGuestPrompt('your account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: BorderSide(
                                color: AppColors.primaryGreen.withAlpha(100),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.login, size: 20),
                            label: const Text(
                              'Sign In to Your Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _authService.signOut(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.errorRed,
                              side: BorderSide(
                                color: AppColors.errorRed.withAlpha(100),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.logout, size: 20),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Only called when [kDebugMode] is true (see call site). Strips out in release via `if (kDebugMode)`.
  Widget _buildDebugPanel(User? user, bool isGuest) {
    assert(kDebugMode, 'Debug panel must not be built outside debug builds');
    final providers = user?.providerData
            .map((u) => u.providerId)
            .toList() ??
        <String>[];
    final providerStr =
        providers.isEmpty ? '(none)' : providers.join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report_outlined,
                size: 18,
                color: const Color(0xFFFFB74D).withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              Text(
                'Debug',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _debugRow('Signed in', user != null ? 'yes' : 'no'),
          _debugRow('Guest (anonymous)', isGuest ? 'yes' : 'no'),
          _debugRow('UID', user?.uid ?? '(null)'),
          _debugRow('Email', user?.email ?? '(none)'),
          _debugRow('Display name', user?.displayName ?? '(none)'),
          _debugRow(
            'Email verified',
            user?.email == null || user!.email!.isEmpty
                ? 'n/a (no email on account)'
                : (user.emailVerified ? 'yes' : 'no'),
          ),
          _debugRow('Providers', providerStr),
          _debugRow(
            'Photo URL',
            (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                ? 'set'
                : '(none)',
          ),
          _debugRow(
            'Created',
            user?.metadata.creationTime?.toIso8601String() ?? '(unknown)',
          ),
          _debugRow(
            'Last sign-in',
            user?.metadata.lastSignInTime?.toIso8601String() ?? '(unknown)',
          ),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF616161), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFBDBDBD),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
