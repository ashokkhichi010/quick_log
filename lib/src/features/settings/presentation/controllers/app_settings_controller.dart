import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/notifications_service.dart';
import '../../../logs/domain/entry_result.dart';
import '../../../logs/domain/log_entry.dart';
import '../../../logs/domain/log_entry_type.dart';
import '../../../logs/domain/repositories/entries_repository.dart';
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
    required EntriesRepository entriesRepository,
    required Uuid uuid,
  }) : _repository = repository,
       _notificationsService = notificationsService,
       _entriesRepository = entriesRepository,
       _uuid = uuid,
       super(const AppSettingsState.initial()) {
    loadSettings();
  }

  final SettingsRepository _repository;
  final NotificationsService _notificationsService;
  final EntriesRepository _entriesRepository;
  final Uuid _uuid;

  Future<void> loadSettings() async {
    final settings = await _repository.fetchSettings();
    state = state.copyWith(settings: settings, isLoading: false);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _persist(state.settings.copyWith(themeMode: mode));
  }

  Future<void> checkIn() async {
    if (state.settings.isCheckedIn) {
      return;
    }

    final checkInTime = DateTime.now();
    final nextSettings = state.settings.copyWith(
      isCheckedIn: true,
      activeSessionStartedAt: checkInTime,
    );
    await _persist(nextSettings);
    await _entriesRepository.saveEntry(
      LogEntry.sessionEvent(
        id: _uuid.v4(),
        type: LogEntryType.checkIn,
        timestamp: checkInTime,
      ),
    );
    await _syncNotifications(nextSettings);
  }

  Future<void> checkOut() async {
    if (!state.settings.isCheckedIn) {
      return;
    }

    final checkOutTime = DateTime.now();
    final nextSettings = state.settings.copyWith(
      isCheckedIn: false,
      activeSessionStartedAt: null,
      lastCheckedOutAt: checkOutTime,
    );
    await _persist(nextSettings);
    await _entriesRepository.saveEntry(
      LogEntry.sessionEvent(
        id: _uuid.v4(),
        type: LogEntryType.checkOut,
        timestamp: checkOutTime,
      ),
    );
    await _syncNotifications(nextSettings);
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
    if (!settings.remindersEnabled || !settings.isCheckedIn) {
      await _notificationsService.cancelAllReminders();
      return;
    }

    await _notificationsService.scheduleIntervalReminder(
      intervalMinutes: settings.reminderIntervalMinutes,
      message: settings.reminderMessage,
    );
  }
}
