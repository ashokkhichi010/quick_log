import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  static const _notificationId = 9001;

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
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
      importance: Importance.defaultImportance,
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
    final granted = await androidImplementation
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  @override
  Future<void> scheduleIntervalReminder({
    required int intervalMinutes,
    required String message,
  }) async {
    await cancelAllReminders();

    await _plugin.periodicallyShowWithDuration(
      id: _notificationId,
      title: 'Quick Log',
      body: message,
      repeatDurationInterval: Duration(minutes: intervalMinutes),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Quick Log reminders',
          channelDescription:
              'Reminders to capture work updates throughout the day.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
    );
  }

  @override
  Future<void> cancelAllReminders() async {
    await _plugin.cancel(id: _notificationId);
  }
}
