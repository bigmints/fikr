/// NotificationService — OS-level scheduled local notifications for reminders.
///
/// This service wraps flutter_local_notifications to schedule notifications at
/// a precise future time. Unlike the in-app timer approach, these notifications
/// fire even when the app is closed or backgrounded.
///
/// Usage:
///   await NotificationService.instance.initialize();
///   await NotificationService.instance.scheduleReminder(reminder);
///   await NotificationService.instance.cancelReminder(reminderId);
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/insights_models.dart';

/// Top-level background notification handler.
/// MUST be a top-level function (not a closure or instance method) and MUST
/// carry the @pragma annotation so the Dart tree-shaker preserves it in AOT.
/// Runs in a separate background isolate — no GetX, no BuildContext.
@pragma('vm:entry-point')
void _notificationBackgroundHandler(NotificationResponse response) {
  // Minimal work only — no service access
  debugPrint('NotificationService [bg]: id=${response.id} payload=${response.payload}');
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Timezone data is needed for scheduled notifications
      tz_data.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const macosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macosSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: _notificationBackgroundHandler,
      );

      _initialized = true;
      debugPrint('NotificationService: initialized.');
    } catch (e) {
      // Plugin not available (e.g. unit test environment)
      debugPrint('NotificationService: skipping — platform not available: $e');
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Request OS-level notification permission.
  /// Returns true if granted (or already granted).
  Future<bool> requestPermission() async {
    try {
      final iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final macosPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      if (macosPlugin != null) {
        final granted = await macosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted =
            await androidPlugin.requestNotificationsPermission() ?? false;
        return granted;
      }

      return true; // Other platforms (desktop) — assume granted
    } catch (e) {
      debugPrint('NotificationService.requestPermission: $e');
      return false;
    }
  }

  // ── Scheduling ─────────────────────────────────────────────────────────────

  /// Schedule an OS-level notification for a [ReminderItem].
  /// If the reminder's due time is in the past, shows it immediately.
  Future<void> scheduleReminder(ReminderItem reminder) async {
    if (!_initialized) await initialize();
    if (!_initialized) return; // Still not initialized (test env) — skip

    final dueTime = _resolvedue(reminder);
    final notificationId = _idFor(reminder.id);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'fikr_reminders',
        'Reminders',
        channelDescription: 'Scheduled reminder notifications from Fikr',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final now = DateTime.now();

    if (dueTime.isBefore(now) || dueTime.isAtSameMomentAs(now)) {
      // Due in the past — show immediately
      await _plugin.show(
        notificationId,
        'Reminder',
        reminder.title,
        notificationDetails,
        payload: reminder.id,
      );
    } else {
      // Schedule for future
      final tzDue = tz.TZDateTime.from(dueTime, tz.local);
      await _plugin.zonedSchedule(
        notificationId,
        'Reminder',
        reminder.title,
        tzDue,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
      debugPrint('NotificationService: scheduled "${reminder.title}" for $dueTime');
    }
  }

  /// Cancel the scheduled notification for a reminder.
  Future<void> cancelReminder(String reminderId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_idFor(reminderId));
      debugPrint('NotificationService: cancelled notification for $reminderId');
    } catch (e) {
      debugPrint('NotificationService.cancelReminder: $e');
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _resolvedue(ReminderItem reminder) {
    DateTime due = reminder.date;
    if (reminder.time != null && reminder.time!.isNotEmpty) {
      try {
        final parts = reminder.time!.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          due = DateTime(
            reminder.date.year,
            reminder.date.month,
            reminder.date.day,
            h,
            m,
          );
        }
      } catch (_) {}
    }
    return due;
  }

  /// Map reminder string ID to a stable int for flutter_local_notifications.
  int _idFor(String id) => id.hashCode.abs() % 2147483647;

  void _onNotificationTap(NotificationResponse response) {
    // Future: navigate to the reminder detail screen
    debugPrint('NotificationService: tapped — payload=${response.payload}');
  }
}
