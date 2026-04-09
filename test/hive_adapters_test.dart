import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:quick_log/src/core/storage/hive_adapters.dart';
import 'package:quick_log/src/features/logs/domain/entry_result.dart';
import 'package:quick_log/src/features/settings/domain/app_settings.dart';

void main() {
  test('AppSettingsAdapter reads legacy settings payloads safely', () {
    final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl)
      ..writeByte(6)
      ..writeByte(0)
      ..write(AppThemeMode.dark.index)
      ..writeByte(1)
      ..write(true)
      ..writeByte(2)
      ..write(30)
      ..writeByte(3)
      ..write('Log your current task')
      ..writeByte(4)
      ..write('flutter')
      ..writeByte(5)
      ..write(EntryResult.worked.index);

    final reader = BinaryReaderImpl(writer.toBytes(), TypeRegistryImpl.nullImpl);
    final settings = AppSettingsAdapter().read(reader);

    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.remindersEnabled, isTrue);
    expect(settings.reminderIntervalMinutes, 30);
    expect(settings.reminderMessage, 'Log your current task');
    expect(settings.isCheckedIn, isFalse);
    expect(settings.activeSessionStartedAt, isNull);
    expect(settings.lastCheckedOutAt, isNull);
    expect(settings.lastUsedCategoryId, 'flutter');
    expect(settings.lastUsedResult, EntryResult.worked);
  });
}
