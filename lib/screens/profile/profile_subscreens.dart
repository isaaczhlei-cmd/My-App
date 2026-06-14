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
    final themeColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Flight History')),
      body: SafeArea(
        child: StreamBuilder<List<Flight>>(
          stream: _firestoreService.getFlightsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
                      Text(
                        'No flights yet',
                        style: TextStyle(
                          color: themeColors.onCard,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your saved flights will appear here.',
                        style: TextStyle(
                          color: themeColors.onCardMuted,
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
              itemBuilder: (context, index) {
                final flight = flights[index];
                return Dismissible(
                  key: Key(flight.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    _firestoreService.deleteFlight(flight.id);
                  },
                  child: FlightCard(flight: flight),
                );
              },
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
        if (mounted) _notificationInbox.markAllRead();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load notifications.',
                  style: TextStyle(color: themeColors.onCardMuted),
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
                              color: themeColors.card,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: themeColors.outlineSoft,
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_outlined,
                              color: themeColors.onCardMuted,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: themeColors.onCard,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Missed eco tips will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: themeColors.onCardMuted,
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
                      // Allow swiping both left and right
                      direction: DismissDirection.horizontal,
                      // Background when swiping to the right (shows on the left)
                      background: const _DeleteNotificationBackground(
                        alignment: Alignment.centerLeft,
                      ),
                      // Background when swiping to the left (shows on the right)
                      secondaryBackground: const _DeleteNotificationBackground(
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
    final themeColors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead
            ? themeColors.card
            : themeColors.successContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.isRead
              ? themeColors.outlineSoft
              : primary.withAlpha(110),
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
                  ? themeColors.cardMuted
                  : primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco,
              color: notification.isRead ? themeColors.onCardMuted : primary,
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
                              ? themeColors.onCard
                              : themeColors.onSuccessContainer,
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
                            ? themeColors.onCardMuted
                            : themeColors.onSuccessContainer,
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
                        ? themeColors.onCardMuted
                        : themeColors.onSuccessContainer,
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

// ── Settings screen ────────────────────────────────────────────────────────

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final themeColors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: themeColors.onCard,
            size: 20,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight, color: themeColors.onCard, size: 16),
            const SizedBox(width: 8),
            Text(
              'Settings',
              style: TextStyle(
                color: themeColors.onCard,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: UserPreferencesService.instance,
        builder: (context, _) {
          final prefs = UserPreferencesService.instance;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                children: [
                  // ── Section 1: Preferences ─────────────────────────────
                  _TicketCard(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.airline_seat_recline_extra_outlined,
                                color: themeColors.onCard,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Default cabin',
                                style: TextStyle(
                                  color: themeColors.onCard,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              _InlineSegmented(
                                options: const [
                                  'Economy',
                                  'Premium',
                                  'Business',
                                ],
                                selected: switch (prefs.defaultCabinClass) {
                                  CabinClass.premiumEconomy => 1,
                                  CabinClass.business || CabinClass.first => 2,
                                  _ => 0,
                                },
                                onSelect: (i) =>
                                    prefs.setDefaultCabinClass(switch (i) {
                                      1 => CabinClass.premiumEconomy,
                                      2 => CabinClass.business,
                                      _ => CabinClass.economy,
                                    }),
                                activeColor: accent,
                              ),
                            ],
                          ),
                        ),
                        const _TicketDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.eco_outlined,
                                color: themeColors.onCard,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'CO₂ unit',
                                style: TextStyle(
                                  color: themeColors.onCard,
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
                                activeColor: accent,
                              ),
                            ],
                          ),
                        ),
                        const _TicketDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.straighten_outlined,
                                color: themeColors.onCard,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Distance',
                                style: TextStyle(
                                  color: themeColors.onCard,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              _InlineSegmented(
                                options: const ['Miles', 'km'],
                                selected:
                                    prefs.distanceUnit == DistanceUnit.miles
                                    ? 0
                                    : 1,
                                onSelect: (i) => prefs.setDistanceUnit(
                                  i == 0 ? DistanceUnit.miles : DistanceUnit.km,
                                ),
                                activeColor: accent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 2: Notifications ───────────────────────────
                  _TicketCard(
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

                  const SizedBox(height: 12),

                  // ── Section 3: Integrations ────────────────────────────
                  _TicketCard(
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
                        Positioned(
                          right: 10,
                          bottom: 4,
                          child: Opacity(
                            opacity: 0.07,
                            child: Icon(
                              Icons.verified_outlined,
                              size: 60,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 4: Appearance ──────────────────────────────
                  _TicketCard(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.contrast_outlined,
                                color: themeColors.onCard,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Theme',
                                style: TextStyle(
                                  color: themeColors.onCard,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              _InlineSegmented(
                                options: const ['Dark', 'Light', 'Auto'],
                                selected: switch (prefs.themeMode) {
                                  ThemeMode.light => 1,
                                  ThemeMode.system => 2,
                                  _ => 0,
                                },
                                onSelect: (i) => prefs.setThemeMode(switch (i) {
                                  1 => ThemeMode.light,
                                  2 => ThemeMode.system,
                                  _ => ThemeMode.dark,
                                }),
                                activeColor: accent,
                              ),
                            ],
                          ),
                        ),
                        const _TicketDivider(),
                        _AccentColorRow(prefs: prefs),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 5: About ───────────────────────────────────
                  _TicketCard(
                    child: _ChevronRow(
                      icon: Icons.info_outline_rounded,
                      label: 'About',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Accent color row ───────────────────────────────────────────────────────

class _AccentColorRow extends StatelessWidget {
  const _AccentColorRow({required this.prefs});

  final UserPreferencesService prefs;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: themeColors.onCard, size: 20),
          const SizedBox(width: 12),
          Text(
            'Accent',
            style: TextStyle(
              color: themeColors.onCard,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: UserPreferencesService.accentPresets.map((preset) {
              final isSelected = prefs.accentColor == preset.color;
              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: GestureDetector(
                  onTap: () => prefs.setAccentColor(preset.color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: preset.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: preset.color,
                                spreadRadius: 2.5,
                                blurRadius: 0,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
    final themeColors = context.appColors;

    return ClipPath(
      clipper: const _TicketEdgeClipper(),
      child: Container(color: themeColors.card, child: child),
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
  });

  final List<String> options;
  final int selected;
  final void Function(int) onSelect;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColors.outlineSoft),
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
                  color: isSelected ? Colors.white : themeColors.onCard,
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

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final themeColors = context.appColors;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: themeColors.onCard, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: accent,
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

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: themeColors.onCard, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: TextStyle(color: themeColors.onCardMuted, fontSize: 14),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: themeColors.onCardMuted,
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
    return Divider(height: 1, indent: 48, color: context.appColors.outlineSoft);
  }
}

// ── About screen ──────────────────────────────────────────────────────────

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flight Carbon Tracker',
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your flights and estimate CO₂ impact to fly more consciously.',
                style: TextStyle(
                  color: themeColors.onCardMuted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Powered by Google Travel Impact Model API',
                style: TextStyle(color: themeColors.onCardMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
