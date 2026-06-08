import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/notification_service.dart';

class ReminderDialog extends StatelessWidget {
  final String profileName;
  final String dateString; // YYYY-MM-DD
  final int notificationId;

  const ReminderDialog({
    super.key,
    required this.profileName,
    required this.dateString,
    required this.notificationId,
  });

  // Returns true when a reminder was successfully scheduled, false otherwise.
  static Future<bool> show(
    BuildContext context,
    String profileName,
    String dateString, {
    required int notificationId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReminderDialog(
        profileName: profileName,
        dateString: dateString,
        notificationId: notificationId,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    // Attempt to parse date for display
    DateTime? parsedDate;
    String displayDate = dateString;
    try {
      parsedDate = DateTime.parse(dateString);
      displayDate = DateFormat.yMMMMd(context.locale.languageCode).format(parsedDate);
    } catch (_) {}

    return AlertDialog(
      title: Text('notification.title'.tr()),
      content: Text('notification.message'.tr(args: [profileName, displayDate])),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () async {
            if (parsedDate != null) {
              // PALETTE: Default to 09:00 on the advised date; SettingsScreen
              // lets users pick a custom time if they prefer.
              final scheduledAt = DateTime(
                parsedDate.year,
                parsedDate.month,
                parsedDate.day,
                9,
                0,
                0,
              );
              try {
                await NotificationService().scheduleReadingReminder(
                  id: notificationId,
                  profileName: profileName,
                  scheduledDate: scheduledAt,
                  title: 'notification.title'.tr(),
                  body: 'notification.message'
                      .tr(args: [profileName, displayDate]),
                );
                if (context.mounted) {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'notification.scheduled'
                                  .tr(args: [displayDate]),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
                return;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('notification.error_schedule'.tr()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
            if (context.mounted) Navigator.pop(context, false);
          },
          child: Text('common.ok'.tr()),
        ),
      ],
    );
  }
}
