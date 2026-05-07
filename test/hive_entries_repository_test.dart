import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quick_log/core/storage/hive_adapters.dart';
import 'package:quick_log/features/logs/data/hive_entries_repository.dart';
import 'package:quick_log/features/logs/domain/entry_result.dart';
import 'package:quick_log/features/logs/domain/log_entry.dart';
import 'package:quick_log/features/logs/domain/log_entry_flavor.dart';
import 'package:quick_log/features/logs/domain/log_entry_type.dart';

void main() {
  late Directory tempDirectory;
  late Box<LogEntry> box;
  late HiveEntriesRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('quick_log_test_');
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(LogEntryAdapter.hiveTypeId)) {
      Hive.registerAdapter(LogEntryAdapter());
    }
    box = await Hive.openBox<LogEntry>('entries_test_box');
    repository = HiveEntriesRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('saves, fetches, reassigns, and deletes entries', () async {
    final olderEntry = LogEntry(
      id: 'one',
      timestamp: DateTime(2026, 4, 8, 9),
      task: 'Debugged sensor issues',
      categoryId: 'iot',
      entryType: LogEntryType.manual,
      flavor: LogEntryFlavor.legacyStructured,
      transcript: null,
      problem: null,
      solutionTried: null,
      result: EntryResult.partial,
      notes: null,
      isImportant: false,
      archivedAt: null,
      deletedAt: null,
      createdAt: DateTime(2026, 4, 8, 9),
      updatedAt: DateTime(2026, 4, 8, 9),
    );
    final newerEntry = LogEntry(
      id: 'two',
      timestamp: DateTime(2026, 4, 8, 11),
      task: 'Shipped quick-add UI',
      categoryId: 'flutter',
      entryType: LogEntryType.manual,
      flavor: LogEntryFlavor.voice,
      transcript: 'Shipped quick-add UI',
      problem: null,
      solutionTried: null,
      result: EntryResult.worked,
      notes: null,
      isImportant: true,
      archivedAt: null,
      deletedAt: null,
      createdAt: DateTime(2026, 4, 8, 11),
      updatedAt: DateTime(2026, 4, 8, 11),
    );

    await repository.saveEntry(olderEntry);
    await repository.saveEntry(newerEntry);

    final fetched = await repository.fetchEntries();
    expect(fetched.map((entry) => entry.id), ['two', 'one']);

    await repository.reassignCategory(
      fromCategoryId: 'iot',
      toCategoryId: 'default-other',
    );

    final reassigned = await repository.fetchEntries();
    expect(
      reassigned.firstWhere((entry) => entry.id == 'one').categoryId,
      'default-other',
    );

    await repository.deleteEntry('two');
    final afterDelete = await repository.fetchEntries();
    expect(afterDelete, hasLength(1));
    expect(afterDelete.single.id, 'one');
  });
}
