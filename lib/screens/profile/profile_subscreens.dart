import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../models/flight.dart';
import '../../services/airline_directory_service.dart';
import '../../services/booking_provider_service.dart';
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

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load your flight history. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themeColors.onCard,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _firestoreService = FirestoreService();
  late final TextEditingController _airplaneAirlineController;
  late final FocusNode _airplaneAirlineFocusNode;
  late final Future<List<AirlineOption>> _airlinesFuture;
  BookingProvider _selectedProvider = BookingProvider.automatic;
  bool _isExportingFlightHistory = false;

  @override
  void initState() {
    super.initState();
    _airplaneAirlineController = TextEditingController(
      text: UserPreferencesService.instance.airplaneModeAirlineName,
    );
    _airplaneAirlineFocusNode = FocusNode();
    _airlinesFuture = AirlineDirectoryService.instance.loadAirlines();
    _loadBookingProvider();
  }

  @override
  void dispose() {
    _airplaneAirlineController.dispose();
    _airplaneAirlineFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBookingProvider() async {
    final provider = await BookingProviderService.getSelectedProvider();
    if (!mounted) return;
    setState(() {
      _selectedProvider = provider;
    });
  }

  Future<void> _showBookingProviderSheet() async {
    const providers = [
      BookingProvider.googleFlights,
      BookingProvider.kayak,
      BookingProvider.skyscanner,
      BookingProvider.automatic,
    ];
    final provider = await showCupertinoModalPopup<BookingProvider>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Booking Provider'),
          actions: providers.map((provider) {
            final isSelected = provider == _selectedProvider;
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(provider),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.displayName),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.check_mark, size: 18),
                  ],
                ],
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (provider == null) return;
    await BookingProviderService.setSelectedProvider(provider);
    if (!mounted) return;
    setState(() {
      _selectedProvider = provider;
    });
  }

  Future<void> _shareFlightHistory() async {
    setState(() {
      _isExportingFlightHistory = true;
    });

    try {
      final flights = await _firestoreService.getFlights();
      if (!mounted) return;

      if (flights.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No flight history to export yet')),
        );
        return;
      }

      final csv = _buildFlightHistoryCsv(flights);
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        name: 'FlightPrint-history.csv',
      );
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: 'FlightPrint flight history',
          text: 'Sharing my FlightPrint flight history.',
          files: [file],
          fileNameOverrides: const ['FlightPrint-history.csv'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export flight history')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingFlightHistory = false;
        });
      }
    }
  }

  String _buildFlightHistoryCsv(List<Flight> flights) {
    final rows = <List<Object?>>[
      [
        'Date',
        'Origin',
        'Destination',
        'Cabin',
        'Emissions kg CO2',
        'Airline',
        'Flight number',
      ],
      ...flights.map(
        (flight) => [
          _isoDate(flight.date),
          flight.originCode,
          flight.destinationCode,
          flight.travelClass,
          flight.emissionsKg.toStringAsFixed(1),
          flight.AirlineCode,
          flight.AirlineNumber,
        ],
      ),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

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
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                96 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                children: [
                  // ── Section 1: Preferences ─────────────────────────────
                  _TicketCard(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cabinSegment = _InlineSegmented(
                                options: const [
                                  'Economy',
                                  'Premium',
                                  'Business',
                                  'First',
                                ],
                                selected: switch (prefs.defaultCabinClass) {
                                  CabinClass.premiumEconomy => 1,
                                  CabinClass.business => 2,
                                  CabinClass.first => 3,
                                  _ => 0,
                                },
                                onSelect: (i) =>
                                    prefs.setDefaultCabinClass(switch (i) {
                                      1 => CabinClass.premiumEconomy,
                                      2 => CabinClass.business,
                                      3 => CabinClass.first,
                                      _ => CabinClass.economy,
                                    }),
                                activeColor: accent,
                              );

                              final label = Row(
                                mainAxisSize: MainAxisSize.min,
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
                                ],
                              );

                              if (constraints.maxWidth < 360) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label,
                                    const SizedBox(height: 12),
                                    cabinSegment,
                                  ],
                                );
                              }

                              return Row(
                                children: [label, const Spacer(), cabinSegment],
                              );
                            },
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
                                options: const ['Kg', 'T'],
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
                                options: const ['Mi', 'Km'],
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
                        const _TicketDivider(),
                        _ToggleRow(
                          icon: Icons.flight_takeoff_outlined,
                          label: 'Airplane mode',
                          value: prefs.tinyFlightAnimationEnabled,
                          onChanged: prefs.setTinyFlightAnimationEnabled,
                        ),
                        if (prefs.tinyFlightAnimationEnabled) ...[
                          const _TicketDivider(),
                          _AirplaneModeAirlineField(
                            controller: _airplaneAirlineController,
                            focusNode: _airplaneAirlineFocusNode,
                            airlinesFuture: _airlinesFuture,
                            onChanged: prefs.setAirplaneModeAirlineName,
                            onSelected: (airline) {
                              _airplaneAirlineController.text = airline.name;
                              prefs.setAirplaneModeAirline(airline);
                              _airplaneAirlineFocusNode.unfocus();
                            },
                          ),
                        ],
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
                              value: _selectedProvider.displayName,
                              onTap: _showBookingProviderSheet,
                            ),
                            const _TicketDivider(),
                            _ChevronRow(
                              icon: Icons.ios_share_outlined,
                              label: 'Export flight history',
                              value: _isExportingFlightHistory
                                  ? 'Preparing'
                                  : null,
                              onTap: _isExportingFlightHistory
                                  ? () {}
                                  : _shareFlightHistory,
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

// ── Settings group card ───────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ── Native segmented control ──────────────────────────────────────────────

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

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: activeColor,
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: selected,
        backgroundColor: themeColors.cardMuted,
        thumbColor: activeColor,
        padding: const EdgeInsets.all(2),
        onValueChanged: (value) {
          if (value != null) onSelect(value);
        },
        children: {
          for (var i = 0; i < options.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: i == selected ? Colors.white : themeColors.onCard,
                ),
              ),
            ),
        },
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

class _AirplaneModeAirlineField extends StatefulWidget {
  const _AirplaneModeAirlineField({
    required this.controller,
    required this.focusNode,
    required this.airlinesFuture,
    required this.onChanged,
    required this.onSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<List<AirlineOption>> airlinesFuture;
  final ValueChanged<String> onChanged;
  final ValueChanged<AirlineOption> onSelected;

  @override
  State<_AirplaneModeAirlineField> createState() =>
      _AirplaneModeAirlineFieldState();
}

class _AirplaneModeAirlineFieldState extends State<_AirplaneModeAirlineField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.airlines, color: themeColors.onCard, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  cursorColor: accent,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    color: themeColors.onCard,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Airline on plane',
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search,
                      color: themeColors.onCardMuted,
                      size: 20,
                    ),
                    suffixIcon: widget.controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              widget.controller.text = 'FlightPrint Air';
                              widget.onChanged('FlightPrint Air');
                              widget.controller.selection =
                                  TextSelection.collapsed(
                                    offset: widget.controller.text.length,
                                  );
                            },
                            icon: Icon(
                              Icons.close,
                              color: themeColors.onCardMuted,
                              size: 18,
                            ),
                          ),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
          if (UserPreferencesService.instance.airplaneModeAirlineCode
                  .trim()
                  .isNotEmpty &&
              UserPreferencesService.instance.airplaneModeAirlineCode !=
                  'FP') ...[
            const SizedBox(height: 10),
            _SelectedAirlinePreview(
              name: UserPreferencesService.instance.airplaneModeAirlineName,
              code: UserPreferencesService.instance.airplaneModeAirlineCode,
              country:
                  UserPreferencesService.instance.airplaneModeAirlineCountry,
            ),
          ],
          if (widget.focusNode.hasFocus) ...[
            const SizedBox(height: 10),
            FutureBuilder<List<AirlineOption>>(
              future: widget.airlinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                if (snapshot.hasError) {
                  return Text(
                    'Airline list unavailable.',
                    style: TextStyle(
                      color: themeColors.onCardMuted,
                      fontSize: 13,
                    ),
                  );
                }
                final airlines = snapshot.data ?? const <AirlineOption>[];
                return _AirlineDropdown(
                  airlines: airlines
                      .where(
                        (airline) =>
                            airline.active &&
                            (airline.iata.isNotEmpty ||
                                airline.icao.isNotEmpty),
                      )
                      .toList(),
                  query: widget.controller.text,
                  onSelected: widget.onSelected,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedAirlinePreview extends StatelessWidget {
  const _SelectedAirlinePreview({
    required this.name,
    required this.code,
    required this.country,
  });

  final String name;
  final String code;
  final String country;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final meta = [
      if (code.isNotEmpty) code,
      if (country.isNotEmpty) country,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Row(
        children: [
          _AirlineLogoBadge(code: code, name: name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: themeColors.onCard,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(
                      color: themeColors.onCardMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AirlineDropdown extends StatelessWidget {
  const _AirlineDropdown({
    required this.airlines,
    required this.query,
    required this.onSelected,
  });

  final List<AirlineOption> airlines;
  final String query;
  final ValueChanged<AirlineOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final normalized = query.trim().toLowerCase();
    final groups = _groupedMatches(normalized);

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: themeColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: groups.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No close airline matches.',
                style: TextStyle(color: themeColors.onCardMuted, fontSize: 13),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: groups.fold<int>(
                0,
                (count, group) => count + 1 + group.options.length,
              ),
              itemBuilder: (context, flatIndex) {
                var cursor = 0;
                for (final group in groups) {
                  if (flatIndex == cursor) {
                    return _AirlineLetterHeader(label: group.letter);
                  }
                  cursor++;
                  final optionIndex = flatIndex - cursor;
                  if (optionIndex >= 0 && optionIndex < group.options.length) {
                    final option = group.options[optionIndex];
                    return _AirlineOptionTile(
                      option: option,
                      onTap: () => onSelected(option),
                    );
                  }
                  cursor += group.options.length;
                }
                return const SizedBox.shrink();
              },
            ),
    );
  }

  List<_AirlineGroup> _groupedMatches(String normalized) {
    final matches = normalized.isEmpty
        ? airlines
        : airlines.where((airline) => airline.searchText.contains(normalized));
    final limited = matches.take(normalized.length <= 1 ? 140 : 36).toList();

    if (normalized.length == 1 && RegExp(r'[a-z]').hasMatch(normalized)) {
      final letter = normalized.toUpperCase();
      return [
        _AirlineGroup(
          letter: letter,
          options: limited
              .where((airline) => airline.initial == letter)
              .take(36)
              .toList(),
        ),
      ];
    }

    if (normalized.length > 1) {
      return [_AirlineGroup(letter: 'Closest Matches', options: limited)];
    }

    final grouped = <String, List<AirlineOption>>{};
    for (final airline in limited) {
      grouped.putIfAbsent(airline.initial, () => []).add(airline);
    }
    final letters = grouped.keys.toList()..sort();
    return letters
        .map(
          (letter) => _AirlineGroup(letter: letter, options: grouped[letter]!),
        )
        .toList();
  }
}

class _AirlineGroup {
  const _AirlineGroup({required this.letter, required this.options});

  final String letter;
  final List<AirlineOption> options;
}

class _AirlineLetterHeader extends StatelessWidget {
  const _AirlineLetterHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      color: themeColors.card,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AirlineOptionTile extends StatelessWidget {
  const _AirlineOptionTile({required this.option, required this.onTap});

  final AirlineOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final code = option.iata.isNotEmpty
        ? option.iata
        : option.icao.isNotEmpty
        ? option.icao
        : '';
    final meta = [
      if (code.isNotEmpty) code,
      if (option.country.isNotEmpty) option.country,
      if (option.active) 'Active',
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _AirlineLogoBadge(code: code, name: option.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: TextStyle(
                      color: themeColors.onCard,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: TextStyle(
                        color: themeColors.onCardMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirlineLogoBadge extends StatelessWidget {
  const _AirlineLogoBadge({required this.code, required this.name});

  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    final label = code.isNotEmpty
        ? code
        : name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: code.length == 2
          ? Image.network(
              'https://www.gstatic.com/flights/airline_logos/70px/$code.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _AirlineLogoFallback(label: label),
            )
          : _AirlineLogoFallback(label: label),
    );
  }
}

class _AirlineLogoFallback extends StatelessWidget {
  const _AirlineLogoFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.flight_takeoff, color: accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FlightPrint',
                          style: TextStyle(
                            color: themeColors.onCard,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fly with a clearer footprint.',
                          style: TextStyle(
                            color: themeColors.onCardMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _AboutSection(
                title: 'What FlightPrint Does',
                body:
                    'FlightPrint helps travelers log flights, estimate carbon impact, compare cleaner route options, and understand aviation emissions in plain language.',
              ),
              const SizedBox(height: 14),
              _AboutSection(
                title: 'How Emissions Work',
                body:
                    'Calculations combine available flight data, cabin class, passenger count, and route distance. When exact model data is unavailable, FlightPrint uses a local distance-based estimate so you can still compare trips consistently.',
              ),
              const SizedBox(height: 14),
              _AboutSection(
                title: 'Why It Matters',
                body:
                    'Carbon numbers can feel abstract, so the app translates totals into trends, milestones, and real-world equivalents like driving distance and home energy use.',
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeColors.outlineSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AboutBullet(
                      icon: Icons.map_outlined,
                      text: 'Visual route maps and monthly emission trends',
                    ),
                    const SizedBox(height: 12),
                    _AboutBullet(
                      icon: Icons.eco_outlined,
                      text: 'Eco tips and carbon equivalency storytelling',
                    ),
                    const SizedBox(height: 12),
                    _AboutBullet(
                      icon: Icons.ios_share_outlined,
                      text: 'Exportable flight history for your own records',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Data source',
                style: TextStyle(
                  color: themeColors.onCard,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Powered by Google Travel Impact Model API when available, with route-distance fallback estimates for continuity.',
                style: TextStyle(
                  color: themeColors.onCardMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: themeColors.onCard,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            color: themeColors.onCardMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _AboutBullet extends StatelessWidget {
  const _AboutBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: themeColors.onCard,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
