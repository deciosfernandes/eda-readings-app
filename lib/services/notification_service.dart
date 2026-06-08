import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

/// Service for managing local notifications and reading reminders.
///
/// **PALETTE**: Enhances UX by providing timely reminders based on the
/// recommended submission windows provided by the EDA API.
///
/// **SENTINEL**: Respects user privacy by handling platform-specific
/// permission requests (e.g., Android 13+) during initialization.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notification plugin and configures platform-specific settings.
  ///
  /// **SENTINEL**: Requests necessary permissions on Android 13+ devices.
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

    const InitializationSettings initializationSettings =
        InitializationSettings(
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
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  /// Schedules a local notification reminder for a specific date.
  ///
  /// The reminder is automatically set to 9:00 AM on the [scheduledDate].
  /// [id] should be a unique identifier for the notification to avoid collisions.
  Future<void> scheduleReadingReminder({
    required int id,
    required String profileName,
    required DateTime scheduledDate,
    String? title,
    String? body,
  }) async {
    // PALETTE: Use the full scheduledDate (date + time) passed by the caller,
    // allowing users to choose any time rather than being forced to 09:00.
    // Callers that want 09:00 should pass a DateTime with hour=9, minute=0.
    if (scheduledDate.isBefore(DateTime.now())) {
      // If the date is already past or today, we don't schedule it for the past
      return;
    }

    final tz.TZDateTime tzDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title ?? 'Reading Reminder - $profileName',
      body ?? 'It is time to send your electricity meter reading to EDA.',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reminders',
          'Reading Reminders',
          channelDescription:
              'Notifications to remind you to send your meter readings',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _notificationsPlugin.cancel(id);

  Future<void> cancelAll() => _notificationsPlugin.cancelAll();
}
