import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // PALETTE: Initialize timezone data to ensure reading reminders are scheduled
    // correctly according to the user's local time, providing a consistent UX.
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed
      },
    );

    // SENTINEL: Handle platform-specific permission requests (e.g., Android 13+)
    // to ensure compliance with OS security models and respect user privacy preferences.
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleReadingReminder({
    required int id,
    required String profileName,
    required DateTime scheduledDate,
    String? title,
    String? body,
  }) async {
    // Set time to 9:00 AM on the target date
    final scheduledDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9, 0, 0,
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      // If the date is already past or today, we don't schedule it for the past
      return;
    }

    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id,
      title ?? 'Lembrete de Leitura - $profileName',
      body ?? 'Está na altura de enviar a leitura da sua eletricidade para a EDA.',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reminders',
          'Reading Reminders',
          channelDescription: 'Notifications to remind you to send your meter readings',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
