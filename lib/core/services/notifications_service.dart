import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderAlertEvent {
  const ReminderAlertEvent({
    required this.message,
    required this.notificationId,
    required this.triggeredAt,
  });

  final String message;
  final int notificationId;
  final DateTime triggeredAt;
}

abstract class NotificationsService {
  Future<void> initialize();

  Future<bool> ensurePermissions();

  Future<void> scheduleIntervalReminder({
    required int intervalMinutes,
    required String message,
  });

  Future<void> cancelAllReminders();

  Stream<ReminderAlertEvent> get reminderAlerts;

  bool get hasPendingReminderAlert;

  ReminderAlertEvent? consumeInitialReminderAlert();
}

class LocalNotificationsService implements NotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'quick_log_reminders';
  static const _notificationIdStart = 9000;
  static const _maxReminderSlotsPerDay = 48;
  static const _payloadType = 'quick_log_reminder';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<ReminderAlertEvent> _reminderAlertsController =
      StreamController<ReminderAlertEvent>.broadcast();

  bool _timezoneReady = false;
  ReminderAlertEvent? _initialReminderAlert;

  @override
  Stream<ReminderAlertEvent> get reminderAlerts =>
      _reminderAlertsController.stream;

  @override
  bool get hasPendingReminderAlert => _initialReminderAlert != null;

  @override
  ReminderAlertEvent? consumeInitialReminderAlert() {
    final reminderAlert = _initialReminderAlert;
    _initialReminderAlert = null;
    return reminderAlert;
  }

  @override
  Future<void> initialize() async {
    await _configureLocalTimezone();

    const androidInitialization = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInitialization),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchedFromNotification =
        launchDetails?.didNotificationLaunchApp ?? false;
    if (launchedFromNotification) {
      _initialReminderAlert = _reminderAlertFromPayload(
        payload: launchDetails?.notificationResponse?.payload,
        notificationId: launchDetails?.notificationResponse?.id,
      );
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      'Quick Log reminders',
      description: 'Reminders to capture work updates throughout the day.',
      importance: Importance.max,
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
    if (!(exactAlarmGranted ?? true)) {
      return false;
    }

    await androidImplementation?.requestFullScreenIntentPermission();
    return true;
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
        title: 'Quick Log reminder',
        body: message,
        scheduledDate: _nextSlotOccurrence(slotMinutes[index]),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _encodePayload(message),
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
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ticker: 'Quick Log reminder',
      playSound: true,
      enableVibration: true,
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

  void _handleNotificationResponse(NotificationResponse response) {
    final reminderAlert = _reminderAlertFromPayload(
      payload: response.payload,
      notificationId: response.id,
    );
    if (reminderAlert != null) {
      _reminderAlertsController.add(reminderAlert);
    }
  }

  String _encodePayload(String message) {
    return jsonEncode(<String, String>{
      'type': _payloadType,
      'message': message,
    });
  }

  ReminderAlertEvent? _reminderAlertFromPayload({
    required String? payload,
    required int? notificationId,
  }) {
    if (payload == null) {
      return ReminderAlertEvent(
        message: 'What are you working on?',
        notificationId: notificationId ?? _notificationIdStart,
        triggeredAt: DateTime.now(),
      );
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic> && decoded['type'] == _payloadType) {
        return ReminderAlertEvent(
          message: decoded['message'] as String? ?? 'What are you working on?',
          notificationId: notificationId ?? _notificationIdStart,
          triggeredAt: DateTime.now(),
        );
      }
    } catch (_) {
      return ReminderAlertEvent(
        message: payload,
        notificationId: notificationId ?? _notificationIdStart,
        triggeredAt: DateTime.now(),
      );
    }

    return null;
  }
}
