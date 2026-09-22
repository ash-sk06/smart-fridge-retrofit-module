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

    // Create high-importance notification channel for Android 8.0+
    final androidChannel = AndroidNotificationChannel(
      lowStockChannelId,
      lowStockChannelName,
      description: lowStockChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidChannel);
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

  /// Showcase test notification for faculty presentation
  Future<void> showTestNotification() async {
    await showLowStockNotification(
      itemName: 'Pasteurized Whole Milk',
      remainingVolumeMl: 145,
      fillPercentage: 15,
      zoneId: 'zone1',
    );
  }
}
