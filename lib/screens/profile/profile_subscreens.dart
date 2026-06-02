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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.track_changes_outlined,
                      color: Theme.of(ctx).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Annual CO₂ Goal',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set your target in ${unit == Co2Unit.kg ? 'kg' : 'metric tons'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: unit == Co2Unit.kg ? 'e.g. 2000' : 'e.g. 2.0',
                    errorText: errorText,
                    suffixText: unit == Co2Unit.kg ? 'kg' : 'tons',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(ctx).colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              if (existingTons != null)
                TextButton(
                  onPressed: () {
                    prefs.setAnnualCo2GoalTons(null);
                    Navigator.of(ctx).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                  child: const Text('Clear'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
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
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PickerSheet(
        title: 'Default Cabin Class',
        subtitle: 'Pre-selected when you add a new flight',
        options: CabinClass.values.map((c) => (c.displayName, c == prefs.defaultCabinClass)).toList(),
        onSelected: (index) => prefs.setDefaultCabinClass(CabinClass.values[index]),
      ),
    );
  }

  Future<void> _showCo2UnitPicker(BuildContext context, UserPreferencesService prefs) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PickerSheet(
        title: 'CO₂ Display Unit',
        subtitle: 'How emissions are shown throughout the app',
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
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PickerSheet(
        title: 'Distance Unit',
        subtitle: 'Shown in your home dashboard stats',
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
          final accent = Theme.of(context).colorScheme.primary;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── APPEARANCE ───────────────────────────────────────────
                  _SectionHeader(label: 'Appearance'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      // Theme mode row
                      _IconSettingsRow(
                        icon: Icons.contrast,
                        iconColor: const Color(0xFF5C6BC0),
                        iconBg: const Color(0xFFE8EAF6),
                        label: 'Theme',
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined, size: 16),
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined, size: 16),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.phone_android_outlined, size: 16),
                              label: Text('System'),
                            ),
                          ],
                          selected: {prefs.themeMode},
                          onSelectionChanged: (modes) => prefs.setThemeMode(modes.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: accent,
                            selectedForegroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[200]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const _CardDivider(),
                      // Accent color row
                      _IconSettingsRow(
                        icon: Icons.palette_outlined,
                        iconColor: accent,
                        iconBg: accent.withAlpha(24),
                        label: 'Accent Color',
                        child: _AccentColorPicker(prefs: prefs),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── GOALS ────────────────────────────────────────────────
                  _SectionHeader(label: 'Goals'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.track_changes_outlined,
                        iconColor: const Color(0xFF26A69A),
                        iconBg: const Color(0xFFE0F2F1),
                        label: 'Annual CO₂ Goal',
                        subtitle: 'Track progress on your home dashboard',
                        value: _formatGoal(prefs.annualCo2GoalTons, prefs.co2Unit),
                        valueHighlight: prefs.annualCo2GoalTons != null,
                        trailingClear: prefs.annualCo2GoalTons != null
                            ? () => prefs.setAnnualCo2GoalTons(null)
                            : null,
                        onTap: () => _showGoalDialog(context, prefs),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── FLIGHT TRACKING ──────────────────────────────────────
                  _SectionHeader(label: 'Flight Tracking'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.airline_seat_recline_extra_outlined,
                        iconColor: const Color(0xFF7E57C2),
                        iconBg: const Color(0xFFEDE7F6),
                        label: 'Default Cabin Class',
                        value: _cabinLabel(prefs.defaultCabinClass),
                        onTap: () => _showCabinPicker(context, prefs),
                      ),
                      const _CardDivider(),
                      _SettingsTile(
                        icon: Icons.co2_outlined,
                        iconColor: const Color(0xFF43A047),
                        iconBg: const Color(0xFFE8F5E9),
                        label: 'CO₂ Display Unit',
                        value: _co2UnitLabel(prefs.co2Unit),
                        onTap: () => _showCo2UnitPicker(context, prefs),
                      ),
                      const _CardDivider(),
                      _SettingsTile(
                        icon: Icons.straighten_outlined,
                        iconColor: const Color(0xFFFF8F00),
                        iconBg: const Color(0xFFFFF3E0),
                        label: 'Distance Unit',
                        value: _distanceUnitLabel(prefs.distanceUnit),
                        onTap: () => _showDistancePicker(context, prefs),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── ECO TIPS ─────────────────────────────────────────────
                  _SectionHeader(label: 'Eco Tips'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SwitchTile(
                        icon: Icons.eco_outlined,
                        iconColor: const Color(0xFF43A047),
                        iconBg: const Color(0xFFE8F5E9),
                        label: 'Tip Notifications',
                        subtitle: 'AI tips based on your flight patterns',
                        value: prefs.ecoTipsEnabled,
                        onChanged: prefs.setEcoTipsEnabled,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Accent color picker ────────────────────────────────────────────────────

class _AccentColorPicker extends StatelessWidget {
  final UserPreferencesService prefs;
  const _AccentColorPicker({required this.prefs});

  @override
  Widget build(BuildContext context) {
    final selectedPreset = UserPreferencesService.accentPresets
        .firstWhere((p) => p.color == prefs.accentColor,
            orElse: () => UserPreferencesService.accentPresets.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: UserPreferencesService.accentPresets.map((preset) {
            final isSelected = prefs.accentColor == preset.color;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => prefs.setAccentColor(preset.color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 44 : 38,
                  height: isSelected ? 44 : 38,
                  decoration: BoxDecoration(
                    color: preset.color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : Border.all(color: Colors.transparent, width: 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: preset.color.withAlpha(120),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          selectedPreset.name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: prefs.accentColor,
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.white,
        child: Column(children: children),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 68,
      endIndent: 0,
      color: Color(0xFFF2F2F2),
    );
  }
}

/// Row with an icon container + label + arbitrary child widget beneath it.
/// Used for theme mode and accent color which have complex controls.
class _IconSettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Widget child;

  const _IconSettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard settings row: icon + label/subtitle + value + chevron.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final String value;
  final bool valueHighlight;
  final VoidCallback? onTap;
  final VoidCallback? trailingClear;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.subtitle,
    required this.value,
    this.valueHighlight = false,
    this.onTap,
    this.trailingClear,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: valueHighlight ? FontWeight.w600 : FontWeight.w400,
                color: valueHighlight ? accent : const Color(0xFF9E9E9E),
              ),
            ),
            if (trailingClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: trailingClear,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Color(0xFF757575)),
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// Toggle row with icon, label, subtitle, and Switch.
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<(String, bool)> options;
  final void Function(int index) onSelected;

  const _PickerSheet({
    required this.title,
    this.subtitle,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ...options.asMap().entries.map((entry) {
            final (label, isSelected) = entry.value;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  onSelected(entry.key);
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? accent : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
                        )
                      else
                        const SizedBox(width: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
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
