import 'package:hive/hive.dart';

import '../domain/log_entry.dart';
import '../domain/repositories/entries_repository.dart';

class HiveEntriesRepository implements EntriesRepository {
  const HiveEntriesRepository(this._box);

  final Box<LogEntry> _box;
  static const trashRetention = Duration(days: 30);

  @override
  Future<List<LogEntry>> fetchEntries() async {
    await _purgeExpiredTrash();
    final entries = _box.values.toList();
    entries.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    return entries;
  }

  @override
  Future<void> saveEntry(LogEntry entry) async {
    await _box.put(entry.id, entry);
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    await _box.delete(entryId);
  }

  @override
  Future<void> permanentlyDeleteEntry(String entryId) async {
    await _box.delete(entryId);
  }

  @override
  Future<void> reassignCategory({
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    final updatedEntries = <LogEntry>[];
    for (final entry in _box.values) {
      if (entry.categoryId == fromCategoryId) {
        updatedEntries.add(
          entry.copyWith(categoryId: toCategoryId, updatedAt: DateTime.now()),
        );
      }
    }

    for (final entry in updatedEntries) {
      await _box.put(entry.id, entry);
    }
  }

  Future<void> _purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(trashRetention);
    final expiredIds = [
      for (final entry in _box.values)
        if (entry.deletedAt != null && entry.deletedAt!.isBefore(cutoff)) entry.id,
    ];

    for (final entryId in expiredIds) {
      await _box.delete(entryId);
    }
  }
}
