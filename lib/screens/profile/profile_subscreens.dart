import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _co2UnitLabel(Co2Unit unit) =>
      unit == Co2Unit.kg ? 'kg' : 'Metric tons';

  String _distanceUnitLabel(DistanceUnit unit) =>
      unit == DistanceUnit.km ? 'km' : 'Miles';

  String _cabinLabel(CabinClass cabin) => cabin.displayName;

  String _formatGoal(double? tons, Co2Unit unit) {
    if (tons == null) return 'Not set';
    if (unit == Co2Unit.kg) {
      return '${(tons * 1000).toStringAsFixed(0)} kg';
    }
    return '${tons.toStringAsFixed(1)} tons';
  }

  // ── Goal dialog ────────────────────────────────────────────────────────────

  Future<void> _showGoalDialog(BuildContext context, UserPreferencesService prefs) async {
    final unit = prefs.co2Unit;
    final existingTons = prefs.annualCo2GoalTons;
    final existingDisplay = existingTons == null
        ? ''
        : unit == Co2Unit.kg
            ? (existingTons * 1000).toStringAsFixed(0)
            : existingTons.toStringAsFixed(1);

    final controller = TextEditingController(text: existingDisplay);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Annual CO₂ Goal (${unit == Co2Unit.kg ? 'kg' : 'tons'})'),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                hintText: unit == Co2Unit.kg ? 'e.g. 2000' : 'e.g. 2.0',
                errorText: errorText,
                suffixText: unit == Co2Unit.kg ? 'kg' : 'tons',
              ),
              autofocus: true,
            ),
            actions: [
              if (existingTons != null)
                TextButton(
                  onPressed: () {
                    prefs.setAnnualCo2GoalTons(null);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Clear Goal'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    prefs.setAnnualCo2GoalTons(null);
                    Navigator.of(ctx).pop();
                    return;
                  }
                  final parsed = double.tryParse(text);
                  if (parsed == null || parsed <= 0) {
                    setDialogState(() => errorText = 'Enter a positive number');
                    return;
                  }
                  final tons = unit == Co2Unit.kg ? parsed / 1000 : parsed;
                  prefs.setAnnualCo2GoalTons(tons);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  // ── Bottom sheet pickers ───────────────────────────────────────────────────

  Future<void> _showCabinPicker(BuildContext context, UserPreferencesService prefs) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _PickerSheet(
        title: 'Default Cabin Class',
        options: CabinClass.values.map((c) => (c.displayName, c == prefs.defaultCabinClass)).toList(),
        onSelected: (index) => prefs.setDefaultCabinClass(CabinClass.values[index]),
      ),
    );
  }

  Future<void> _showCo2UnitPicker(BuildContext context, UserPreferencesService prefs) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _PickerSheet(
        title: 'CO₂ Display Unit',
        options: [
          ('Metric tons', prefs.co2Unit == Co2Unit.metricTons),
          ('kg', prefs.co2Unit == Co2Unit.kg),
        ],
        onSelected: (index) => prefs.setCo2Unit(index == 0 ? Co2Unit.metricTons : Co2Unit.kg),
      ),
    );
  }

  Future<void> _showDistancePicker(BuildContext context, UserPreferencesService prefs) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _PickerSheet(
        title: 'Distance Unit',
        options: [
          ('Miles', prefs.distanceUnit == DistanceUnit.miles),
          ('km', prefs.distanceUnit == DistanceUnit.km),
        ],
        onSelected: (index) => prefs.setDistanceUnit(index == 0 ? DistanceUnit.miles : DistanceUnit.km),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: UserPreferencesService.instance,
        builder: (context, _) {
          final prefs = UserPreferencesService.instance;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── APPEARANCE ───────────────────────────────────────────
                  _SectionHeader(label: 'APPEARANCE'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      // Theme mode
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                                  label: Text('Dark'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined, size: 18),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.phone_android_outlined, size: 18),
                                  label: Text('System'),
                                ),
                              ],
                              selected: {prefs.themeMode},
                              onSelectionChanged: (modes) => prefs.setThemeMode(modes.first),
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                                selectedForegroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _CardDivider(),
                      // Accent color
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Accent Color',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: UserPreferencesService.accentPresets.map((preset) {
                                final isSelected = prefs.accentColor == preset.color;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () => prefs.setAccentColor(preset.color),
                                    child: Tooltip(
                                      message: preset.name,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: preset.color,
                                          shape: BoxShape.circle,
                                          border: isSelected
                                              ? Border.all(color: const Color(0xFF1A1A2E), width: 2.5)
                                              : null,
                                          boxShadow: isSelected
                                              ? [BoxShadow(color: preset.color.withAlpha(100), blurRadius: 8, spreadRadius: 2)]
                                              : null,
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── GOALS ────────────────────────────────────────────────
                  _SectionHeader(label: 'GOALS'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        label: 'Annual CO₂ Goal (${prefs.co2Unit == Co2Unit.kg ? 'kg' : 'tons'})',
                        value: _formatGoal(prefs.annualCo2GoalTons, prefs.co2Unit),
                        trailing: prefs.annualCo2GoalTons != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
                                onPressed: () => prefs.setAnnualCo2GoalTons(null),
                                tooltip: 'Clear goal',
                              )
                            : null,
                        onTap: () => _showGoalDialog(context, prefs),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── FLIGHT TRACKING ──────────────────────────────────────
                  _SectionHeader(label: 'FLIGHT TRACKING'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        label: 'Default Cabin Class',
                        value: _cabinLabel(prefs.defaultCabinClass),
                        onTap: () => _showCabinPicker(context, prefs),
                      ),
                      const _CardDivider(),
                      _SettingsTile(
                        label: 'CO₂ Display Unit',
                        value: _co2UnitLabel(prefs.co2Unit),
                        onTap: () => _showCo2UnitPicker(context, prefs),
                      ),
                      const _CardDivider(),
                      _SettingsTile(
                        label: 'Distance Unit',
                        value: _distanceUnitLabel(prefs.distanceUnit),
                        onTap: () => _showDistancePicker(context, prefs),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── ECO TIPS ─────────────────────────────────────────────
                  _SectionHeader(label: 'ECO TIPS'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Eco Tip Notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: prefs.ecoTipsEnabled,
                              onChanged: prefs.setEcoTipsEnabled,
                              activeThumbColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Column(children: children),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0));
  }
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({required this.label, required this.value, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
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
            Text(
              value,
              style: const TextStyle(fontSize: 15, color: Color(0xFF9E9E9E)),
            ),
            if (trailing != null) trailing!
            else const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right, color: Color(0xFFBDBDBD), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<(String, bool)> options;
  final void Function(int index) onSelected;

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ...options.asMap().entries.map((entry) {
              final (label, isSelected) = entry.value;
              return ListTile(
                title: Text(label),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  onSelected(entry.key);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
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
                'Track your flights and estimate CO\u2082 impact to fly more consciously.',
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
