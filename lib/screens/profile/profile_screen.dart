import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _buildProfileHeader(
                        displayName: displayName,
                        email: email,
                        photoUrl: photoUrl,
                        isGuest: isGuest,
                      ),
                      const SizedBox(height: 18),
                      _buildMenuSection(
                        children: [
                          _buildMenuRow(
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
                              return _buildMenuRow(
                                icon: Icons.notifications_outlined,
                                label: 'Notifications',
                                badgeCount:
                                    _notificationInbox.notifications.length,
                                onTap: () {
                                  if (isGuest) {
                                    _openGuestPrompt('Notifications');
                                  } else {
                                    _pushSignedIn(
                                      const NotificationSettingsScreen(),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                          _buildMenuRow(
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
                          _buildMenuRow(
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
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildAccountActions(isGuest),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader({
    required String displayName,
    required String email,
    required String? photoUrl,
    required bool isGuest,
  }) {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColors.outlineSoft.withAlpha(90)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onAvatarTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (!isGuest && photoUrl != null && photoUrl.isNotEmpty)
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 34,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person, size: 34, color: Colors.white),
                ),
                if (_uploadingPhoto)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: themeColors.onCard,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: themeColors.onCardMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required List<Widget> children}) {
    final themeColors = context.appColors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColors.outlineSoft.withAlpha(90)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 72,
                color: themeColors.outlineSoft.withAlpha(80),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountActions(bool isGuest) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: isGuest
              ? OutlinedButton.icon(
                  onPressed: () => _openGuestPrompt('your account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(120),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.login, size: 20),
                  label: const Text(
                    'Sign In to Your Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () async {
                    await _authService.signOut();
                    if (!mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: BorderSide(color: AppColors.errorRed.withAlpha(120)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
        if (!isGuest) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: _onDeleteAccountTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorRed.withAlpha(185),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final themeColors = context.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: themeColors.cardMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: themeColors.onCardMuted, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
            top: 8,
            right: 10,
            child: NotificationBadge(count: badgeCount),
          ),
      ],
    );
  }
}
