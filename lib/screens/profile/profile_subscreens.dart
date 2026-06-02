import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/emissions_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_inbox_service.dart';
import '../../services/user_preferences_service.dart';
import '../home/widgets/flight_card.dart';

class FlightHistoryScreen extends StatelessWidget {
  FlightHistoryScreen({super.key});

  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Flight History')),
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final flights = snapshot.data ?? [];

            if (flights.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flight, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      const Text(
                        'No flights yet',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your saved flights will appear here.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: flights.length,
              itemBuilder: (context, index) =>
                  FlightCard(flight: flights[index]),
            );
          },
        ),
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _notificationInbox = NotificationInboxService.instance;
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _notificationInbox.load().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notificationInbox.markAllRead();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Failed to load notifications.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return AnimatedBuilder(
              animation: _notificationInbox,
              builder: (context, _) {
                final notifications = _notificationInbox.notifications;

                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Missed eco tips will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Dismissible(
                      key: ValueKey('notification-${notification.id}'),
                      direction: DismissDirection.endToStart,
                      background: const _DeleteNotificationBackground(
                        alignment: Alignment.centerRight,
                      ),
                      onDismissed: (_) {
                        _notificationInbox.deleteNotification(notification.id);
                      },
                      child: _NotificationTile(notification: notification),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DeleteNotificationBackground extends StatelessWidget {
  final Alignment alignment;

  const _DeleteNotificationBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(left: isLeft ? 22 : 0, right: isLeft ? 0 : 22),
      decoration: BoxDecoration(
        color: AppColors.errorRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead
            ? AppColors.cardBackground
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.isRead
              ? Colors.white.withAlpha(18)
              : Theme.of(context).colorScheme.primary.withAlpha(110),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: notification.isRead
                  ? Colors.white.withAlpha(16)
                  : const Color(0xFFC8E6C9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco,
              color: notification.isRead
                  ? AppColors.textSecondary
                  : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          color: notification.isRead
                              ? AppColors.textPrimary
                              : const Color(0xFF2E7D32),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(notification.createdAt),
                      style: TextStyle(
                        color: notification.isRead
                            ? AppColors.textSecondary
                            : const Color(0xFF2E7D32),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: notification.isRead
                        ? AppColors.textSecondary
                        : const Color(0xFF33691E),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final hour = local.hour == 0
          ? 12
          : local.hour > 12
          ? local.hour - 12
          : local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
    return '${local.month}/${local.day}/${local.year}';
  }
}

// ── Settings screen — ticket aesthetic ────────────────────────────────────

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  static const _bgGreen = Color(0xFF1B3120);
  static const _cream = Color(0xFFEFE7CF);
  static const _activeGreen = Color(0xFF2C5530);
  static const _cardText = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGreen,
      body: AnimatedBuilder(
        animation: UserPreferencesService.instance,
        builder: (context, _) {
          final prefs = UserPreferencesService.instance;
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                    child: Column(
                      children: const [
                        Icon(Icons.flight, color: Colors.white, size: 26),
                        SizedBox(height: 6),
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Georgia',
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Section 1: Preferences ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TicketCard(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.airline_seat_recline_extra_outlined,
                                  color: _cardText,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Default cabin',
                                  style: TextStyle(
                                    color: _cardText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                _InlineSegmented(
                                  options: const ['Economy', 'Premium', 'Business'],
                                  selected: switch (prefs.defaultCabinClass) {
                                    CabinClass.premiumEconomy => 1,
                                    CabinClass.business || CabinClass.first => 2,
                                    _ => 0,
                                  },
                                  onSelect: (i) => prefs.setDefaultCabinClass(
                                    switch (i) {
                                      1 => CabinClass.premiumEconomy,
                                      2 => CabinClass.business,
                                      _ => CabinClass.economy,
                                    },
                                  ),
                                  activeColor: _activeGreen,
                                  cardColor: _cream,
                                ),
                              ],
                            ),
                          ),
                          const _TicketDivider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.eco_outlined,
                                  color: _cardText,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Units',
                                  style: TextStyle(
                                    color: _cardText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                _InlineSegmented(
                                  options: const ['kg', 'tons'],
                                  selected: prefs.co2Unit == Co2Unit.kg ? 0 : 1,
                                  onSelect: (i) => prefs.setCo2Unit(
                                    i == 0 ? Co2Unit.kg : Co2Unit.metricTons,
                                  ),
                                  activeColor: _activeGreen,
                                  cardColor: _cream,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 2: Notifications ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TicketCard(
                      child: Column(
                        children: [
                          _ToggleRow(
                            icon: Icons.notifications_outlined,
                            label: 'Eco-tip notifications',
                            value: prefs.ecoTipsEnabled,
                            onChanged: prefs.setEcoTipsEnabled,
                          ),
                          const _TicketDivider(),
                          _ToggleRow(
                            icon: Icons.mail_outline_rounded,
                            label: 'Weekly digest',
                            value: prefs.weeklyDigestEnabled,
                            onChanged: prefs.setWeeklyDigestEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 3: Integrations ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TicketCard(
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              _ChevronRow(
                                icon: Icons.luggage_outlined,
                                label: 'Booking provider',
                                value: 'Automatic',
                                onTap: () {},
                              ),
                              const _TicketDivider(),
                              _ChevronRow(
                                icon: Icons.ios_share_outlined,
                                label: 'Export flight history',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => FlightHistoryScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Passport stamp watermark
                          Positioned(
                            right: 10,
                            bottom: 4,
                            child: Opacity(
                              opacity: 0.10,
                              child: Icon(
                                Icons.verified_outlined,
                                size: 60,
                                color: _activeGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 4: Account ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TicketCard(
                      child: Column(
                        children: [
                          _ChevronRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Account',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const _TicketDivider(),
                          _ChevronRow(
                            icon: Icons.language_outlined,
                            label: 'About',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AboutScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Ticket card with perforated edges ─────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _TicketEdgeClipper(),
      child: Container(
        color: const Color(0xFFEFE7CF),
        child: child,
      ),
    );
  }
}

// ── Perforated edge clipper ────────────────────────────────────────────────

class _TicketEdgeClipper extends CustomClipper<Path> {
  const _TicketEdgeClipper();

  static const double notchRadius = 5.5;

  @override
  Path getClip(Size size) {
    const r = notchRadius;
    final gap = r * 2.2;
    final path = Path();

    // Top edge — notches dip downward into card
    path.moveTo(0, 0);
    double x = gap + r;
    while (x + r < size.width - gap) {
      path.lineTo(x - r, 0);
      path.arcToPoint(
        Offset(x + r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      );
      x += r * 2 + gap;
    }
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);

    // Bottom edge — notches dip upward into card (drawn right to left)
    double bx = size.width - gap - r;
    while (bx - r > gap) {
      path.lineTo(bx + r, size.height);
      path.arcToPoint(
        Offset(bx - r, size.height),
        radius: Radius.circular(r),
        clockwise: true,
      );
      bx -= r * 2 + gap;
    }
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_TicketEdgeClipper old) => false;
}

// ── Inline segmented chip control ─────────────────────────────────────────

class _InlineSegmented extends StatelessWidget {
  const _InlineSegmented({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.activeColor,
    required this.cardColor,
  });

  final List<String> options;
  final int selected;
  final void Function(int) onSelect;
  final Color activeColor;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = i == selected;
          final isFirst = i == 0;
          final isLast = i == options.length - 1;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? const Radius.circular(7) : Radius.zero,
                  right: isLast ? const Radius.circular(7) : Radius.zero,
                ),
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF2A2A2A),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  static const _cardText = Color(0xFF1A1A1A);
  static const _activeGreen = Color(0xFF2C5530);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _cardText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _cardText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: _activeGreen,
              activeThumbColor: Colors.white,
              inactiveTrackColor: Colors.black12,
              inactiveThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chevron row ───────────────────────────────────────────────────────────

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;

  static const _cardText = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: _cardText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _cardText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: TextStyle(
                  color: _cardText.withAlpha(130),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: _cardText.withAlpha(100),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Divider for ticket cards ──────────────────────────────────────────────

class _TicketDivider extends StatelessWidget {
  const _TicketDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 48,
      color: const Color(0xFF1A1A1A).withAlpha(20),
    );
  }
}

// ── About screen ──────────────────────────────────────────────────────────

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('About')),
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
              SizedBox(height: 24),
              Text(
                'Powered by Google Travel Impact Model API',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
