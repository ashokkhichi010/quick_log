import 'package:flutter_test/flutter_test.dart';
import 'package:quick_log/src/features/settings/presentation/controllers/app_settings_controller.dart';

import 'test_doubles.dart';

void main() {
  test('enabling reminders persists settings and schedules notifications', () async {
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
    expect(notifications.scheduledMessage, isNotEmpty);
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
}
