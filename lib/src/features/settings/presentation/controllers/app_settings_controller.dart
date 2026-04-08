import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notifications_service.dart';
import '../../../logs/domain/entry_result.dart';
import '../../domain/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class AppSettingsState {
  const AppSettingsState({required this.settings, required this.isLoading});

  const AppSettingsState.initial()
    : settings = const AppSettings.defaults(),
      isLoading = true;

  final AppSettings settings;
  final bool isLoading;

  AppSettingsState copyWith({AppSettings? settings, bool? isLoading}) {
    return AppSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

enum ReminderToggleResult { updated, permissionDenied }

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController({
    required SettingsRepository repository,
    required NotificationsService notificationsService,
  }) : _repository = repository,
       _notificationsService = notificationsService,
       super(const AppSettingsState.initial()) {
    loadSettings();
  }

  final SettingsRepository _repository;
  final NotificationsService _notificationsService;

  Future<void> loadSettings() async {
    final settings = await _repository.fetchSettings();
    state = state.copyWith(settings: settings, isLoading: false);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _persist(state.settings.copyWith(themeMode: mode));
  }

  Future<ReminderToggleResult> setRemindersEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _notificationsService.ensurePermissions();
      if (!granted) {
        return ReminderToggleResult.permissionDenied;
      }
    }

    final nextSettings = state.settings.copyWith(remindersEnabled: enabled);
    await _persist(nextSettings);
    await _syncNotifications(nextSettings);
    return ReminderToggleResult.updated;
  }

  Future<void> setReminderInterval(int minutes) async {
    final nextSettings = state.settings.copyWith(
      reminderIntervalMinutes: minutes,
    );
    await _persist(nextSettings);
    await _syncNotifications(nextSettings);
  }

  Future<void> setReminderMessage(String message) async {
    final trimmed = message.trim();
    final nextMessage = trimmed.isEmpty
        ? AppSettings.defaultReminderMessage
        : trimmed;
    final nextSettings = state.settings.copyWith(reminderMessage: nextMessage);
    await _persist(nextSettings);
    await _syncNotifications(nextSettings);
  }

  Future<void> rememberLastUsed({
    required String categoryId,
    required EntryResult result,
  }) async {
    await _persist(
      state.settings.copyWith(
        lastUsedCategoryId: categoryId,
        lastUsedResult: result,
      ),
    );
  }

  Future<void> _persist(AppSettings settings) async {
    await _repository.saveSettings(settings);
    state = state.copyWith(settings: settings);
  }

  Future<void> _syncNotifications(AppSettings settings) async {
    if (!settings.remindersEnabled) {
      await _notificationsService.cancelAllReminders();
      return;
    }

    await _notificationsService.scheduleIntervalReminder(
      intervalMinutes: settings.reminderIntervalMinutes,
      message: settings.reminderMessage,
    );
  }
}
