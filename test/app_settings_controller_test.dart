import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_log/src/features/settings/presentation/controllers/app_settings_controller.dart';
import 'package:quick_log/src/features/settings/domain/app_settings.dart';

import 'test_doubles.dart';

void main() {
  test(
    'enabling reminders while checked out persists but does not schedule',
    () async {
      final repository = FakeSettingsRepository();
      final entriesRepository = FakeEntriesRepository();
      final notifications = FakeNotificationsService(permissionGranted: true);
      final controller = AppSettingsController(
        repository: repository,
        notificationsService: notifications,
        entriesRepository: entriesRepository,
        uuid: const Uuid(),
      );

      await controller.loadSettings();
      final result = await controller.setRemindersEnabled(true);

      expect(result, ReminderToggleResult.updated);
      expect(repository.settings.remindersEnabled, isTrue);
      expect(notifications.scheduledIntervalMinutes, isNull);
    },
  );

  test('check in stores event and starts reminders when enabled', () async {
    final repository = FakeSettingsRepository(
      const AppSettings.defaults().copyWith(remindersEnabled: true),
    );
    final entriesRepository = FakeEntriesRepository();
    final notifications = FakeNotificationsService(permissionGranted: true);
    final controller = AppSettingsController(
      repository: repository,
      notificationsService: notifications,
      entriesRepository: entriesRepository,
      uuid: const Uuid(),
    );

    await controller.loadSettings();
    await controller.checkIn();

    expect(repository.settings.isCheckedIn, isTrue);
    expect(notifications.scheduledIntervalMinutes, 60);
    expect(notifications.scheduledMessage, isNotEmpty);
    expect(entriesRepository.entriesSnapshot.single.task, 'Checked in');
  });

  test('permission denial leaves reminder state unchanged', () async {
    final repository = FakeSettingsRepository();
    final entriesRepository = FakeEntriesRepository();
    final notifications = FakeNotificationsService(permissionGranted: false);
    final controller = AppSettingsController(
      repository: repository,
      notificationsService: notifications,
      entriesRepository: entriesRepository,
      uuid: const Uuid(),
    );

    await controller.loadSettings();
    final result = await controller.setRemindersEnabled(true);

    expect(result, ReminderToggleResult.permissionDenied);
    expect(repository.settings.remindersEnabled, isFalse);
    expect(notifications.scheduledIntervalMinutes, isNull);
  });

  test('check out stores event and cancels reminders', () async {
    final repository = FakeSettingsRepository(
      const AppSettings.defaults().copyWith(
        remindersEnabled: true,
        isCheckedIn: true,
        activeSessionStartedAt: DateTime(2026, 4, 9, 9),
      ),
    );
    final entriesRepository = FakeEntriesRepository();
    final notifications = FakeNotificationsService(permissionGranted: true);
    final controller = AppSettingsController(
      repository: repository,
      notificationsService: notifications,
      entriesRepository: entriesRepository,
      uuid: const Uuid(),
    );

    await controller.loadSettings();
    await controller.checkOut();

    expect(repository.settings.isCheckedIn, isFalse);
    expect(notifications.remindersCancelled, isTrue);
    expect(entriesRepository.entriesSnapshot.single.task, 'Checked out');
  });
}
