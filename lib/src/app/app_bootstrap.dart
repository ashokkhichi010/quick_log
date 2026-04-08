import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/hive_boxes.dart';
import '../core/services/export_service.dart';
import '../core/services/notifications_service.dart';
import '../core/storage/hive_adapters.dart';
import '../features/logs/data/hive_categories_repository.dart';
import '../features/logs/data/hive_entries_repository.dart';
import '../features/logs/domain/category.dart';
import '../features/logs/domain/log_entry.dart';
import '../features/settings/data/hive_settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import 'app_providers.dart';

class AppBootstrapData {
  const AppBootstrapData({required this.overrides});

  final List<Override> overrides;
}

Future<AppBootstrapData> bootstrapApp() async {
  await Hive.initFlutter();
  _registerAdapters();

  // Hive keeps the app lightweight here: fast local writes, simple offline
  // setup, no schema-heavy boilerplate, and enough querying flexibility for a
  // compact personal log.
  final entriesBox = await Hive.openBox<LogEntry>(HiveBoxes.entries);
  final categoriesBox = await Hive.openBox<Category>(HiveBoxes.categories);
  final settingsBox = await Hive.openBox<AppSettings>(HiveBoxes.settings);

  final entriesRepository = HiveEntriesRepository(entriesBox);
  final categoriesRepository = HiveCategoriesRepository(categoriesBox);
  final settingsRepository = HiveSettingsRepository(settingsBox);

  await _seedDefaults(
    categoriesRepository: categoriesRepository,
    settingsRepository: settingsRepository,
  );

  final notificationsService = LocalNotificationsService();
  await notificationsService.initialize();

  final settings = await settingsRepository.fetchSettings();
  if (settings.remindersEnabled) {
    await notificationsService.scheduleIntervalReminder(
      intervalMinutes: settings.reminderIntervalMinutes,
      message: settings.reminderMessage,
    );
  }

  return AppBootstrapData(
    overrides: [
      entriesRepositoryProvider.overrideWithValue(entriesRepository),
      categoriesRepositoryProvider.overrideWithValue(categoriesRepository),
      settingsRepositoryProvider.overrideWithValue(settingsRepository),
      notificationsServiceProvider.overrideWithValue(notificationsService),
      exportServiceProvider.overrideWithValue(const LocalExportService()),
    ],
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(LogEntryAdapter.hiveTypeId)) {
    Hive.registerAdapter(LogEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(CategoryAdapter.hiveTypeId)) {
    Hive.registerAdapter(CategoryAdapter());
  }
  if (!Hive.isAdapterRegistered(AppSettingsAdapter.hiveTypeId)) {
    Hive.registerAdapter(AppSettingsAdapter());
  }
}

Future<void> _seedDefaults({
  required HiveCategoriesRepository categoriesRepository,
  required HiveSettingsRepository settingsRepository,
}) async {
  final categories = await categoriesRepository.fetchCategories();
  if (categories.isEmpty) {
    for (final category in Category.seededCategories) {
      await categoriesRepository.saveCategory(category);
    }
  } else if (!categories.any(
    (item) => item.id == Category.fallbackCategoryId,
  )) {
    await categoriesRepository.saveCategory(Category.fallbackCategory());
  }

  await settingsRepository.ensureSettings();
}
