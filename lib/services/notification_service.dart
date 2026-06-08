import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

  // BOLT: Guard against double-initialization (hot-restart, multiple callers).
  bool _initialized = false;

  /// Initializes the notification plugin and configures platform-specific settings.
  ///
  /// **SENTINEL**: Requests necessary permissions on Android 13+ devices.
  /// Idempotent — safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // PALETTE: Initialize timezone data and set the device-local timezone so
    // that reading reminders fire at the user's chosen wall-clock time, not UTC.
    tz.initializeTimeZones();
    try {
      final String localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (e) {
      // Fallback: tz.local stays UTC. Reminders may fire at the wrong hour on
      // this device but the app will not crash.
      debugPrint('NotificationService: could not determine local timezone; '
          'defaulting to UTC. $e');
    }

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

    // SENTINEL: Handle platform-specific permission requests to ensure compliance
    // with OS security models and respect user privacy preferences.
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Android 13+: runtime notification permission.
      final notifGranted = await androidImpl?.requestNotificationsPermission();
      debugPrint('NotificationService: notifications permission = $notifGranted');
      // Android 12+: exact-alarm permission for user-chosen reminder times.
      final exactGranted = await androidImpl?.requestExactAlarmsPermission();
      debugPrint('NotificationService: exact alarm permission = $exactGranted');
    }
  }

  /// Schedules a local notification reminder for a specific date.
  ///
  /// The reminder fires at the exact date+time in [scheduledDate] (local time).
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
      // If the date is already past, do not schedule it.
      return;
    }

    // BOLT/PALETTE: Convert local DateTime to TZDateTime using the device
    // timezone set during initialize(). This ensures the notification fires at
    // the user's chosen wall-clock time even if tz.local differs from UTC.
    final tz.TZDateTime tzDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    // PALETTE: Prefer exactAllowWhileIdle for user-chosen reminder times; the
    // OS may batch inexact alarms substantially delaying the reminder.
    // canScheduleExactNotifications() is only available on Android 12+; on
    // earlier versions null is returned and we default to exact anyway.
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canExact = await androidImpl?.canScheduleExactNotifications();
      if (canExact == false) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

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
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _notificationsPlugin.cancel(id);

  Future<void> cancelAll() => _notificationsPlugin.cancelAll();
}
