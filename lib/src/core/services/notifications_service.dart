import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract class NotificationsService {
  Future<void> initialize();

  Future<bool> ensurePermissions();

  Future<void> scheduleIntervalReminder({
    required int intervalMinutes,
    required String message,
  });

  Future<void> cancelAllReminders();
}

class LocalNotificationsService implements NotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'quick_log_reminders';
  static const _notificationIdStart = 9000;
  static const _maxReminderSlotsPerDay = 48;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _timezoneReady = false;

  @override
  Future<void> initialize() async {
    await _configureLocalTimezone();

    const androidInitialization = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInitialization),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Quick Log reminders',
      description: 'Reminders to capture work updates throughout the day.',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  @override
  Future<bool> ensurePermissions() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final notificationsGranted = await androidImplementation
        ?.requestNotificationsPermission();
    if (!(notificationsGranted ?? true)) {
      return false;
    }

    final exactAlarmGranted = await androidImplementation
        ?.requestExactAlarmsPermission();
    return exactAlarmGranted ?? true;
  }

  @override
  Future<void> scheduleIntervalReminder({
    required int intervalMinutes,
    required String message,
  }) async {
    await _configureLocalTimezone();
    await cancelAllReminders();

    final slotMinutes = _slotMinutesForInterval(intervalMinutes);
    for (var index = 0; index < slotMinutes.length; index++) {
      await _plugin.zonedSchedule(
        id: _notificationIdStart + index,
        title: 'Quick Log',
        body: message,
        scheduledDate: _nextSlotOccurrence(slotMinutes[index]),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  @override
  Future<void> cancelAllReminders() async {
    for (var index = 0; index < _maxReminderSlotsPerDay; index++) {
      await _plugin.cancel(id: _notificationIdStart + index);
    }
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Quick Log reminders',
      channelDescription:
          'Reminders to capture work updates throughout the day.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      ticker: 'Quick Log reminder',
    ),
  );

  List<int> _slotMinutesForInterval(int intervalMinutes) {
    return [
      for (var minute = 0; minute < 24 * 60; minute += intervalMinutes) minute,
    ];
  }

  tz.TZDateTime _nextSlotOccurrence(int minutesFromMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> _configureLocalTimezone() async {
    if (_timezoneReady) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _timezoneReady = true;
  }
}
