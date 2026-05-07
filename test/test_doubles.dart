import 'dart:async';

import 'package:quick_log/core/models/export_format.dart';
import 'package:quick_log/core/services/export_service.dart';
import 'package:quick_log/core/services/notifications_service.dart';
import 'package:quick_log/features/logs/domain/category.dart';
import 'package:quick_log/features/logs/domain/log_entry.dart';
import 'package:quick_log/features/logs/domain/repositories/categories_repository.dart';
import 'package:quick_log/features/logs/domain/repositories/entries_repository.dart';
import 'package:quick_log/features/speech/services/speech_service.dart';
import 'package:quick_log/features/settings/domain/app_settings.dart';
import 'package:quick_log/features/settings/domain/repositories/settings_repository.dart';

class FakeEntriesRepository implements EntriesRepository {
  FakeEntriesRepository([List<LogEntry>? seedEntries])
    : _entries = [...?seedEntries];

  final List<LogEntry> _entries;

  List<LogEntry> get entriesSnapshot => [..._entries];

  @override
  Future<void> deleteEntry(String entryId) async {
    _entries.removeWhere((item) => item.id == entryId);
  }

  @override
  Future<void> permanentlyDeleteEntry(String entryId) async {
    _entries.removeWhere((item) => item.id == entryId);
  }

  @override
  Future<List<LogEntry>> fetchEntries() async {
    return [..._entries]
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
  }

  @override
  Future<void> reassignCategory({
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (entry.categoryId == fromCategoryId) {
        _entries[index] = entry.copyWith(categoryId: toCategoryId);
      }
    }
  }

  @override
  Future<void> saveEntry(LogEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      _entries.add(entry);
    } else {
      _entries[index] = entry;
    }
  }
}

class FakeCategoriesRepository implements CategoriesRepository {
  FakeCategoriesRepository([List<Category>? seedCategories])
    : _categories = [...(seedCategories ?? Category.seededCategories)];

  final List<Category> _categories;

  @override
  Future<void> deleteCategory(String categoryId) async {
    _categories.removeWhere((item) => item.id == categoryId);
  }

  @override
  Future<List<Category>> fetchCategories() async {
    return [..._categories];
  }

  @override
  Future<void> saveCategory(Category category) async {
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
  }
}

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([AppSettings? seedSettings])
    : settings = seedSettings ?? const AppSettings.defaults();

  AppSettings settings;

  @override
  Future<AppSettings> fetchSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings nextSettings) async {
    settings = nextSettings;
  }
}

class FakeNotificationsService implements NotificationsService {
  FakeNotificationsService({this.permissionGranted = true});

  bool permissionGranted;
  int? scheduledIntervalMinutes;
  String? scheduledMessage;
  bool remindersCancelled = false;
  bool initialized = false;
  ReminderAlertEvent? initialReminderAlert;
  final StreamController<ReminderAlertEvent> _reminderAlertsController =
      StreamController<ReminderAlertEvent>.broadcast();

  @override
  Stream<ReminderAlertEvent> get reminderAlerts =>
      _reminderAlertsController.stream;

  @override
  bool get hasPendingReminderAlert => initialReminderAlert != null;

  @override
  ReminderAlertEvent? consumeInitialReminderAlert() {
    final reminderAlert = initialReminderAlert;
    initialReminderAlert = null;
    return reminderAlert;
  }

  @override
  Future<void> cancelAllReminders() async {
    remindersCancelled = true;
  }

  @override
  Future<bool> ensurePermissions() async => permissionGranted;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> scheduleIntervalReminder({
    required int intervalMinutes,
    required String message,
  }) async {
    scheduledIntervalMinutes = intervalMinutes;
    scheduledMessage = message;
  }

  void emitReminderAlert(ReminderAlertEvent event) {
    _reminderAlertsController.add(event);
  }
}

class FakeSpeechService implements SpeechService {
  FakeSpeechService({
    this.permissionState = SpeechPermissionState.granted,
    this.available = true,
    this.locale = const SpeechLocaleOption(
      localeId: 'en-IN',
      name: 'English (India)',
    ),
  });

  SpeechPermissionState permissionState;
  bool available;
  SpeechLocaleOption? locale;
  bool _isListening = false;
  void Function(String words, bool isFinal)? _resultCallback;
  void Function(String status)? _statusCallback;
  void Function(String errorMessage, bool permanent)? _errorCallback;

  @override
  SpeechLocaleOption? get activeLocale => locale;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _statusCallback?.call('notListening');
  }

  @override
  Future<bool> checkAvailability() async => available;

  @override
  Future<SpeechPermissionState> ensureMicrophonePermission() async {
    return permissionState;
  }

  @override
  Future<SpeechAvailability> initialize() async {
    return SpeechAvailability(
      isAvailable: available,
      activeLocale: locale,
      locales: locale == null ? const [] : [locale!],
    );
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function(String errorMessage, bool permanent) onError,
  }) async {
    _isListening = true;
    _resultCallback = onResult;
    _statusCallback = onStatus;
    _errorCallback = onError;
    _statusCallback?.call('listening');
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _statusCallback?.call('done');
  }

  void emitResult(String words, {bool isFinal = false}) {
    _resultCallback?.call(words, isFinal);
  }

  void emitError(String message, {bool permanent = true}) {
    _isListening = false;
    _errorCallback?.call(message, permanent);
  }
}

class FakeExportService implements ExportService {
  ExportFormat? lastFormat;

  @override
  Future<ExportResult> exportEntries({
    required ExportFormat format,
    required List<LogEntry> entries,
    required List<Category> categories,
  }) async {
    lastFormat = format;
    return ExportResult(
      filePath: '/tmp/quick_log.${format.extension}',
      fileName: 'quick_log${format.extension}',
    );
  }
}
