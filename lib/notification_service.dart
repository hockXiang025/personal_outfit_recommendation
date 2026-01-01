import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:rxdart/rxdart.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Stream to listen to notification clicks
  static final onNotifications = BehaviorSubject<String?>();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize with onDidReceiveNotificationResponse
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // When taps notification, add payload to the stream
        onNotifications.add(response.payload);
      },
    );
  }

  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleOutfitNotification({
    int? id,
    required DateTime date,
    required TimeOfDay time,
    required String topName,
    required String bottomName,
    required Map<String, dynamic> fullOutfitData,
  }) async {

    int notificationId = id ?? int.parse("${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}");
    final scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (scheduledDate.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Today Suggestion', // Title
      bottomName.isEmpty ? 'Wear: $topName' : 'Wear: $topName + $bottomName', // Body
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'outfit_channel',
          'Outfit Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(fullOutfitData), // Save data inside notification
    );
  }
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}