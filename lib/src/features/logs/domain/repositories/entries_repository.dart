import '../log_entry.dart';

abstract class EntriesRepository {
  Future<List<LogEntry>> fetchEntries();

  Future<void> saveEntry(LogEntry entry);

  Future<void> deleteEntry(String entryId);

  Future<void> reassignCategory({
    required String fromCategoryId,
    required String toCategoryId,
  });
}
