import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'eco_tip_service.dart';

class DailyPushSchedulerService {
  DailyPushSchedulerService._();

  static final DailyPushSchedulerService instance =
      DailyPushSchedulerService._();

  static const int _notificationId = 1001;
  static const String _permissionGrantedKey = 'daily_push_permission_granted';
  static const String _permissionDeniedKey = 'daily_push_permission_denied';
  static const int _deliveryHour = 9;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final EcoTipService _ecoTipService = EcoTipService();
  bool _initialized = false;

  Future<void> ensureScheduled() async {
    try {
      await _initPlugin();
      final granted = await _requestPermission();
      if (!granted) return;
      if (await _isPendingNotificationScheduled()) return;
      final tip = await _fetchTip();
      await _scheduleNext(tip);
    } catch (e) {
      // Non-fatal: daily push is best-effort
    }
  }

  Future<void> _initPlugin() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_permissionDeniedKey) == true) return false;
    if (prefs.getBool(_permissionGrantedKey) == true) return true;

    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final granted =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    await prefs.setBool(
      granted ? _permissionGrantedKey : _permissionDeniedKey,
      true,
    );
    return granted;
  }

  Future<bool> _isPendingNotificationScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => n.id == _notificationId);
  }

  Future<EcoTipSuggestion> _fetchTip() async {
    try {
      return await _ecoTipService.fetchEcoTip(
        flightCount: 0,
        totalEmissionsKg: 0,
        recentTravelPattern: 'general',
      );
    } catch (_) {
      final tips = EcoTipService.fallbackTips;
      return tips[math.Random().nextInt(tips.length)];
    }
  }

  Future<void> _scheduleNext(EcoTipSuggestion tip) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, _deliveryHour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notificationId,
      'Eco Tip',
      tip.tip,
      scheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void dispose() {
    _ecoTipService.dispose();
  }
}
