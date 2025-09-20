import 'dart:io';
import 'package:flutter/services.dart';

class NotificationPermissionHelper {
  static const MethodChannel _channel = MethodChannel('vpnControl');

  static Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return; // iOS not handled here
    try {
      await _channel.invokeMethod('request_notifications');
    } catch (_) {}
  }

  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('open_app_settings');
    } catch (_) {}
  }
}
