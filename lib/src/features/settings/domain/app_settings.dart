import 'package:flutter/material.dart';

import '../../logs/domain/category.dart';
import '../../logs/domain/entry_result.dart';

const _settingsUnset = Object();

enum AppThemeMode { light, dark }

extension AppThemeModeX on AppThemeMode {
  ThemeMode get asThemeMode => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.remindersEnabled,
    required this.reminderIntervalMinutes,
    required this.reminderMessage,
    required this.lastUsedCategoryId,
    required this.lastUsedResult,
  });

  const AppSettings.defaults()
    : themeMode = AppThemeMode.light,
      remindersEnabled = false,
      reminderIntervalMinutes = 60,
      reminderMessage = defaultReminderMessage,
      lastUsedCategoryId = Category.fallbackCategoryId,
      lastUsedResult = EntryResult.partial;

  static const defaultReminderMessage = 'What are you working on?';

  final AppThemeMode themeMode;
  final bool remindersEnabled;
  final int reminderIntervalMinutes;
  final String reminderMessage;
  final String lastUsedCategoryId;
  final EntryResult lastUsedResult;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? remindersEnabled,
    int? reminderIntervalMinutes,
    String? reminderMessage,
    Object? lastUsedCategoryId = _settingsUnset,
    EntryResult? lastUsedResult,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      reminderMessage: reminderMessage ?? this.reminderMessage,
      lastUsedCategoryId: identical(lastUsedCategoryId, _settingsUnset)
          ? this.lastUsedCategoryId
          : lastUsedCategoryId as String,
      lastUsedResult: lastUsedResult ?? this.lastUsedResult,
    );
  }
}
