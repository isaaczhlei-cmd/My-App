import 'package:flutter/services.dart';

class AppIconBadgeService {
  AppIconBadgeService._();

  static const MethodChannel _channel = MethodChannel('my_app/app_icon_badge');

  static Future<void> setBadgeCount(int count) async {
    try {
      await _channel.invokeMethod<void>('setBadgeCount', count);
    } on MissingPluginException {
      // Platforms without a native badge implementation can ignore this.
    } on PlatformException {
      // Badge permission can be denied by iOS settings; keep the in-app badge.
    }
  }
}
