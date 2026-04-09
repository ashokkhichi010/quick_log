import 'category.dart';
import 'entry_result.dart';
import 'log_entry_type.dart';

const _unset = Object();

class LogEntry {
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.task,
    required this.categoryId,
    required this.entryType,
    required this.problem,
    required this.solutionTried,
    required this.result,
    required this.notes,
    required this.isImportant,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime timestamp;
  final String task;
  final String categoryId;
  final LogEntryType entryType;
  final String? problem;
  final String? solutionTried;
  final EntryResult result;
  final String? notes;
  final bool isImportant;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LogEntry.create({required String id, required LogEntryDraft draft}) {
    final now = DateTime.now();
    return LogEntry(
      id: id,
      timestamp: draft.timestamp,
      task: draft.task.trim(),
      categoryId: draft.categoryId,
      entryType: LogEntryType.manual,
      problem: _normalizeText(draft.problem),
      solutionTried: _normalizeText(draft.solutionTried),
      result: draft.result,
      notes: _normalizeText(draft.notes),
      isImportant: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory LogEntry.sessionEvent({
    required String id,
    required LogEntryType type,
    DateTime? timestamp,
  }) {
    assert(type != LogEntryType.manual, 'Use LogEntry.create for manual logs.');
    final eventTime = timestamp ?? DateTime.now();
    final (task, notes) = switch (type) {
      LogEntryType.checkIn => ('Checked in', 'Work session started'),
      LogEntryType.checkOut => ('Checked out', 'Work session ended'),
      LogEntryType.manual => ('Activity', null),
    };

    return LogEntry(
      id: id,
      timestamp: eventTime,
      task: task,
      categoryId: Category.fallbackCategoryId,
      entryType: type,
      problem: null,
      solutionTried: null,
      result: EntryResult.partial,
      notes: notes,
      isImportant: false,
      createdAt: eventTime,
      updatedAt: eventTime,
    );
  }

  LogEntry applyDraft(LogEntryDraft draft) {
    return copyWith(
      timestamp: draft.timestamp,
      task: draft.task.trim(),
      categoryId: draft.categoryId,
      entryType: LogEntryType.manual,
      problem: _normalizeText(draft.problem),
      solutionTried: _normalizeText(draft.solutionTried),
      result: draft.result,
      notes: _normalizeText(draft.notes),
      updatedAt: DateTime.now(),
    );
  }

  LogEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? task,
    String? categoryId,
    LogEntryType? entryType,
    Object? problem = _unset,
    Object? solutionTried = _unset,
    EntryResult? result,
    Object? notes = _unset,
    bool? isImportant,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      task: task ?? this.task,
      categoryId: categoryId ?? this.categoryId,
      entryType: entryType ?? this.entryType,
      problem: identical(problem, _unset) ? this.problem : problem as String?,
      solutionTried: identical(solutionTried, _unset)
          ? this.solutionTried
          : solutionTried as String?,
      result: result ?? this.result,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      isImportant: isImportant ?? this.isImportant,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isSessionEvent => entryType != LogEntryType.manual;

  bool get isEditable => !isSessionEvent;

  static String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class LogEntryDraft {
  const LogEntryDraft({
    required this.timestamp,
    required this.task,
    required this.categoryId,
    required this.result,
    this.problem,
    this.solutionTried,
    this.notes,
  });

  final DateTime timestamp;
  final String task;
  final String categoryId;
  final String? problem;
  final String? solutionTried;
  final EntryResult result;
  final String? notes;
}
