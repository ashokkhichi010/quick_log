import 'package:hive/hive.dart';

import '../../features/logs/domain/category.dart';
import '../../features/logs/domain/entry_result.dart';
import '../../features/logs/domain/log_entry.dart';
import '../../features/logs/domain/log_entry_type.dart';
import '../../features/settings/domain/app_settings.dart';

class LogEntryAdapter extends TypeAdapter<LogEntry> {
  static const hiveTypeId = 1;

  @override
  final int typeId = hiveTypeId;

  @override
  LogEntry read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };

    return LogEntry(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      task: fields[2] as String,
      categoryId: fields[3] as String,
      entryType: fields.containsKey(11)
          ? LogEntryType.values[fields[11] as int]
          : LogEntryType.manual,
      problem: fields[4] as String?,
      solutionTried: fields[5] as String?,
      result: EntryResult.values[fields[6] as int],
      notes: fields[7] as String?,
      isImportant: fields[8] as bool,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LogEntry obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.task)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.problem)
      ..writeByte(5)
      ..write(obj.solutionTried)
      ..writeByte(6)
      ..write(obj.result.index)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.isImportant)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.entryType.index);
  }
}

class CategoryAdapter extends TypeAdapter<Category> {
  static const hiveTypeId = 2;

  @override
  final int typeId = hiveTypeId;

  @override
  Category read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };

    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      isDefault: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isDefault);
  }
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  static const hiveTypeId = 3;

  @override
  final int typeId = hiveTypeId;

  @override
  AppSettings read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };

    final rawCheckedIn = fields[4];
    final rawSessionStartedAt = fields[5];
    final rawCheckedOutAt = fields[6];
    final rawLastUsedCategoryId = fields[7];
    final rawLastUsedResult = fields[8];

    final lastUsedCategoryId =
        rawLastUsedCategoryId is String
            ? rawLastUsedCategoryId
            : rawCheckedIn is String
            ? rawCheckedIn
            : Category.fallbackCategoryId;
    final lastUsedResultIndex =
        rawLastUsedResult is int
            ? rawLastUsedResult
            : rawSessionStartedAt is int
            ? rawSessionStartedAt
            : EntryResult.partial.index;

    return AppSettings(
      themeMode: AppThemeMode.values[fields[0] as int],
      remindersEnabled: fields[1] as bool,
      reminderIntervalMinutes: fields[2] as int,
      reminderMessage: fields[3] as String,
      isCheckedIn: rawCheckedIn is bool ? rawCheckedIn : false,
      activeSessionStartedAt: rawSessionStartedAt is DateTime
          ? rawSessionStartedAt
          : null,
      lastCheckedOutAt: rawCheckedOutAt is DateTime ? rawCheckedOutAt : null,
      lastUsedCategoryId: lastUsedCategoryId,
      lastUsedResult: EntryResult.values[lastUsedResultIndex],
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.themeMode.index)
      ..writeByte(1)
      ..write(obj.remindersEnabled)
      ..writeByte(2)
      ..write(obj.reminderIntervalMinutes)
      ..writeByte(3)
      ..write(obj.reminderMessage)
      ..writeByte(4)
      ..write(obj.isCheckedIn)
      ..writeByte(5)
      ..write(obj.activeSessionStartedAt)
      ..writeByte(6)
      ..write(obj.lastCheckedOutAt)
      ..writeByte(7)
      ..write(obj.lastUsedCategoryId)
      ..writeByte(8)
      ..write(obj.lastUsedResult.index);
  }
}
