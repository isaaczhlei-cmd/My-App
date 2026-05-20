import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_icon_badge_service.dart';
import 'eco_tip_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    required this.isRead,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class NotificationInboxService extends ChangeNotifier {
  NotificationInboxService._();

  static final NotificationInboxService instance = NotificationInboxService._();

  static const _notificationsPrefsKey = 'app_notifications';
  static const _deliveredEcoTipKeysPrefsKey = 'delivered_eco_tip_keys';

  final List<AppNotification> _notifications = <AppNotification>[];
  final Set<String> _deliveredEcoTipKeys = <String>{};
  bool _isLoaded = false;
  Future<void>? _loadFuture;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount {
    return _notifications.where((notification) => !notification.isRead).length;
  }

  Future<void> load() {
    if (_isLoaded) return Future.value();
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNotifications =
        prefs.getStringList(_notificationsPrefsKey) ?? const <String>[];
    _notifications
      ..clear()
      ..addAll(savedNotifications.map(_decodeNotification).nonNulls)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _deliveredEcoTipKeys
      ..clear()
      ..addAll(
        prefs.getStringList(_deliveredEcoTipKeysPrefsKey) ?? const <String>[],
      );

    _isLoaded = true;
    await _syncAppIconBadge();
    notifyListeners();
  }

  Future<void> addMissedEcoTip({
    required String deliveryKey,
    required EcoTipSuggestion tip,
  }) async {
    await load();
    if (_deliveredEcoTipKeys.contains(deliveryKey)) return;

    _deliveredEcoTipKeys.add(deliveryKey);
    _notifications.insert(
      0,
      AppNotification(
        id: 'eco-tip-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Eco Tip',
        message: tip.tip,
        category: tip.category,
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );
    await _save();
    await _syncAppIconBadge();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await load();
    if (unreadCount == 0) return;

    for (var index = 0; index < _notifications.length; index++) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
    await _save();
    await _syncAppIconBadge();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await load();
    final removedCount = _notifications.length;
    _notifications.removeWhere((notification) => notification.id == id);
    if (_notifications.length == removedCount) return;

    await _save();
    await _syncAppIconBadge();
    notifyListeners();
  }

  AppNotification? _decodeNotification(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return AppNotification.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _notificationsPrefsKey,
      _notifications
          .map((notification) => jsonEncode(notification.toJson()))
          .toList(),
    );
    await prefs.setStringList(
      _deliveredEcoTipKeysPrefsKey,
      _deliveredEcoTipKeys.toList(),
    );
  }

  Future<void> _syncAppIconBadge() {
    return AppIconBadgeService.setBadgeCount(unreadCount);
  }
}
