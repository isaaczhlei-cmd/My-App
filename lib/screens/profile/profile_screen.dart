import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/notification_inbox_service.dart';
import '../../widgets/notification_badge.dart';
import 'guest_sign_in_prompt_screen.dart';
import 'profile_subscreens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _notificationInbox = NotificationInboxService.instance;
  bool _uploadingPhoto = false;
  bool _showDeveloperDiagnostics = false;

  @override
  void initState() {
    super.initState();
    _notificationInbox.load();
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? 'Update failed')));
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
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _onDeleteAccountTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This is permanent and cannot be undone. All your flights and '
          'profile data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = _authService.currentUser;
    final providerId = user?.providerData.isEmpty == true
        ? ''
        : user?.providerData.first.providerId ?? '';

    String? password;
    if (providerId == 'password') {
      password = await _showPasswordDialog();
      if (password == null || !mounted) return;
    }

    final result = await _authService.deleteAccount(password: password);
    if (!mounted) return;

    if (result.success) {
      // Defer past the current frame so any lingering dialog focus events
      // finish cleanup before we tear down the navigation stack.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not delete account')),
      );
    }
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Current password'),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.userChanges,
      builder: (context, snapshot) {
        final user = _authService.currentUser;
        final isGuest = _authService.isGuest;
        final dn = user?.displayName?.trim();
        final displayName = dn != null && dn.isNotEmpty ? dn : 'Traveler';
        final email = user?.email ?? 'Guest';
        final photoUrl = user?.photoURL;
        final themeColors = context.appColors;

        return Scaffold(
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
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              (!isGuest &&
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: themeColors.onCard,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: themeColors.onCardMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 24),
                  _buildMenuItem(
                    icon: Icons.flight,
                    label: 'Flight History',
                    onTap: () {
                      if (isGuest) {
                        _openGuestPrompt('Flight History');
                      } else {
                        _pushSignedIn(FlightHistoryScreen());
                      }
                    },
                  ),
                  AnimatedBuilder(
                    animation: _notificationInbox,
                    builder: (context, _) {
                      // Show the badge for the total number of notifications
                      // (the white label reflects count); the red circle remains
                      // visible even when the count is zero per design request.
                      return _buildMenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        badgeCount: _notificationInbox.notifications.length,
                        onTap: () {
                          if (isGuest) {
                            _openGuestPrompt('Notifications');
                          } else {
                            _pushSignedIn(const NotificationSettingsScreen());
                          }
                        },
                      );
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
                            onPressed: () => _openGuestPrompt('your account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(100),
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
                            onPressed: () async {
                              await _authService.signOut();
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            },
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
                  if (!isGuest) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton(
                        onPressed: _onDeleteAccountTap,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.errorRed.withAlpha(180),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    _buildDeveloperModeToggle(),
                    if (_showDeveloperDiagnostics) ...[
                      const SizedBox(height: 12),
                      _buildDebugPanel(user, isGuest),
                    ],
                  ],
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
    final providers =
        user?.providerData.map((u) => u.providerId).toList() ?? <String>[];
    final providerStr = providers.isEmpty ? '(none)' : providers.join(', ');
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.6),
        ),
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
    final themeColors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: themeColors.onCardMuted,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: themeColors.onCard,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperModeToggle() {
    return _buildMenuItem(
      icon: Icons.developer_mode,
      label: _showDeveloperDiagnostics
          ? 'Hide Developer Diagnostics'
          : 'Developer Diagnostics',
      onTap: () {
        setState(() {
          _showDeveloperDiagnostics = !_showDeveloperDiagnostics;
        });
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final themeColors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: themeColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeColors.cardMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: themeColors.onCardMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: themeColors.onCard,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: themeColors.onCardMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: NotificationBadge(count: badgeCount),
            ),
        ],
      ),
    );
  }
}
