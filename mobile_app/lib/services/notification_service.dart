import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String lowStockChannelId = 'fridge_low_stock';
  static const String lowStockChannelName = 'ChillSense Stock Alerts';
  static const String lowStockChannelDesc =
      'Sends instant reminders when refrigerator stock drops below minimum capacity';

  static const String doorAjarChannelId = 'fridge_door_ajar';
  static const String doorAjarChannelName = 'ChillSense Door-Ajar Buzzer';
  static const String doorAjarChannelDesc =
      'Triggers buzzer and notifications if magnetic door switch remains open for > 45 seconds';

  static const String coldChainChannelId = 'fridge_cold_chain';
  static const String coldChainChannelName = 'ChillSense Cold-Chain Microclimate';
  static const String coldChainChannelDesc =
      'Alerts user if internal refrigerator temperature exceeds 4.5°C threshold';

  static const int doorAjarNotificationId = 8801;
  static const int coldChainNotificationId = 8802;

  /// Initializes the local notification plugin and configures the Android channel
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Can handle notification click navigation if needed
      },
    );

    // Channels for Android 8.0+
    final lowStockChannel = AndroidNotificationChannel(
      lowStockChannelId,
      lowStockChannelName,
      description: lowStockChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
    );

    final doorAjarChannel = AndroidNotificationChannel(
      doorAjarChannelId,
      doorAjarChannelName,
      description: doorAjarChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
    );

    final coldChainChannel = AndroidNotificationChannel(
      coldChainChannelId,
      coldChainChannelName,
      description: coldChainChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 150, 300]),
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(lowStockChannel);
      await androidImplementation.createNotificationChannel(doorAjarChannel);
      await androidImplementation.createNotificationChannel(coldChainChannel);
      // Request POST_NOTIFICATIONS permission on Android 13+
      await androidImplementation.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Sends a heads-up system push notification for low stock with exact item details
  Future<void> showLowStockNotification({
    required String itemName,
    required int remainingVolumeMl,
    required int fillPercentage,
    required String zoneId,
  }) async {
    await initialize();

    final title = '🚨 Low Stock Alert: $itemName';
    final body =
        '$itemName is running low ($remainingVolumeMl ml remaining • $fillPercentage%). Added to grocery replenishment list.';

    final androidDetails = AndroidNotificationDetails(
      lowStockChannelId,
      lowStockChannelName,
      channelDescription: lowStockChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Low Stock Alert: $itemName',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEF4444),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'ChillSense Refrigerator Retrofit Alert',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final notificationId = zoneId.hashCode.abs() % 10000;
    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Cancels an active notification by ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancels the door-ajar notification when the door is closed
  Future<void> cancelDoorAjarNotification() async {
    await cancelNotification(doorAjarNotificationId);
  }

  /// Sends a Door-Ajar Buzzer & Alert notification (> 45 seconds open)
  Future<void> showDoorAjarNotification({required int durationSec}) async {
    await initialize();

    const title = '🚨 Door-Ajar Alert: Refrigerator Open!';
    final body =
        'Magnetic switch detected refrigerator door open for ${durationSec}s (> 45s threshold). Close door to avoid food spoilage and power waste.';

    final androidDetails = AndroidNotificationDetails(
      doorAjarChannelId,
      doorAjarChannelName,
      channelDescription: doorAjarChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Door-Ajar Buzzer Alert',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFF59E0B),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'ChillSense Magnetic Reed Switch Alert',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      doorAjarNotificationId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Sends a Cold-Chain Microclimate Alert notification (> 4.5°C)
  Future<void> showColdChainAlertNotification({required double temperatureC}) async {
    await initialize();

    const title = '⚠️ Cold-Chain Alert: High Temperature!';
    final body =
        'Internal temperature reached ${temperatureC.toStringAsFixed(1)}°C (threshold: 4.5°C). Cold-chain compromised — check door seal and refrigeration unit.';

    final androidDetails = AndroidNotificationDetails(
      coldChainChannelId,
      coldChainChannelName,
      channelDescription: coldChainChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Cold-Chain Alert: ${temperatureC.toStringAsFixed(1)}°C',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEF4444),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 150, 300]),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'ChillSense Microclimate DHT22 Warning',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      coldChainNotificationId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Showcase test notification for faculty presentation (Low Stock)
  Future<void> showTestNotification() async {
    await showLowStockNotification(
      itemName: 'Pasteurized Whole Milk',
      remainingVolumeMl: 145,
      fillPercentage: 15,
      zoneId: 'zone1',
    );
  }

  /// Showcase test notification for Door-Ajar Buzzer (> 45s)
  Future<void> showTestDoorAjarNotification() async {
    await showDoorAjarNotification(durationSec: 48);
  }

  /// Showcase test notification for Cold-Chain Alert (> 4.5°C)
  Future<void> showTestColdChainNotification() async {
    await showColdChainAlertNotification(temperatureC: 6.4);
  }
}
