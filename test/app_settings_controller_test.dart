import 'package:flutter_test/flutter_test.dart';
import 'package:quick_log/features/settings/domain/app_settings.dart';
import 'package:quick_log/features/settings/presentation/controllers/app_settings_controller.dart';

import 'test_doubles.dart';

void main() {
  test('enabling reminders schedules notifications immediately', () async {
    final repository = FakeSettingsRepository();
    final notifications = FakeNotificationsService(permissionGranted: true);
    final controller = AppSettingsController(
      repository: repository,
      notificationsService: notifications,
    );

    await controller.loadSettings();
    final result = await controller.setRemindersEnabled(true);

    expect(result, ReminderToggleResult.updated);
    expect(repository.settings.remindersEnabled, isTrue);
    expect(notifications.scheduledIntervalMinutes, 60);
  });

  test('permission denial leaves reminder state unchanged', () async {
    final repository = FakeSettingsRepository();
    final notifications = FakeNotificationsService(permissionGranted: false);
    final controller = AppSettingsController(
      repository: repository,
      notificationsService: notifications,
    );

    await controller.loadSettings();
    final result = await controller.setRemindersEnabled(true);

    expect(result, ReminderToggleResult.permissionDenied);
    expect(repository.settings.remindersEnabled, isFalse);
    expect(notifications.scheduledIntervalMinutes, isNull);
  });

  test('changing interval reschedules existing reminders', () async {
    final repository = FakeSettingsRepository(
      const AppSettings.defaults().copyWith(remindersEnabled: true),
    );
    final notifications = FakeNotificationsService(permissionGranted: true);
    final controller = AppSettingsController(
      repository: repository,
      notificationsService: notifications,
    );

    await controller.loadSettings();
    await controller.setReminderInterval(30);

    expect(repository.settings.reminderIntervalMinutes, 30);
    expect(notifications.scheduledIntervalMinutes, 30);
  });
}
