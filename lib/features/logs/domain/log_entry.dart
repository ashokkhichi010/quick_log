import 'category.dart';
import 'entry_result.dart';
import 'log_entry_flavor.dart';
import 'log_entry_type.dart';

const _unset = Object();

class LogEntry {
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.task,
    required this.categoryId,
    required this.entryType,
    required this.flavor,
    required this.transcript,
    required this.problem,
    required this.solutionTried,
    required this.result,
    required this.notes,
    required this.isImportant,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime timestamp;
  final String task;
  final String categoryId;
  final LogEntryType entryType;
  final LogEntryFlavor flavor;
  final String? transcript;
  final String? problem;
  final String? solutionTried;
  final EntryResult result;
  final String? notes;
  final bool isImportant;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
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
      flavor: LogEntryFlavor.legacyStructured,
      transcript: null,
      problem: _normalizeText(draft.problem),
      solutionTried: _normalizeText(draft.solutionTried),
      result: draft.result,
      notes: _normalizeText(draft.notes),
      isImportant: false,
      archivedAt: null,
      deletedAt: null,
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
      flavor: LogEntryFlavor.legacySession,
      transcript: null,
      problem: null,
      solutionTried: null,
      result: EntryResult.partial,
      notes: notes,
      isImportant: false,
      archivedAt: null,
      deletedAt: null,
      createdAt: eventTime,
      updatedAt: eventTime,
    );
  }

  factory LogEntry.voice({
    required String id,
    required String transcript,
    DateTime? createdAt,
    bool isImportant = false,
  }) {
    final now = createdAt ?? DateTime.now();
    final normalizedTranscript = transcript.trim();
    return LogEntry(
      id: id,
      timestamp: now,
      task: normalizedTranscript,
      categoryId: Category.fallbackCategoryId,
      entryType: LogEntryType.manual,
      flavor: LogEntryFlavor.voice,
      transcript: normalizedTranscript,
      problem: null,
      solutionTried: null,
      result: EntryResult.partial,
      notes: null,
      isImportant: isImportant,
      archivedAt: null,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  LogEntry applyDraft(LogEntryDraft draft) {
    return copyWith(
      timestamp: draft.timestamp,
      task: draft.task.trim(),
      categoryId: draft.categoryId,
      entryType: LogEntryType.manual,
      flavor: LogEntryFlavor.legacyStructured,
      transcript: null,
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
    LogEntryFlavor? flavor,
    Object? transcript = _unset,
    Object? problem = _unset,
    Object? solutionTried = _unset,
    EntryResult? result,
    Object? notes = _unset,
    bool? isImportant,
    Object? archivedAt = _unset,
    Object? deletedAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      task: task ?? this.task,
      categoryId: categoryId ?? this.categoryId,
      entryType: entryType ?? this.entryType,
      flavor: flavor ?? this.flavor,
      transcript: identical(transcript, _unset)
          ? this.transcript
          : transcript as String?,
      problem: identical(problem, _unset) ? this.problem : problem as String?,
      solutionTried: identical(solutionTried, _unset)
          ? this.solutionTried
          : solutionTried as String?,
      result: result ?? this.result,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      isImportant: isImportant ?? this.isImportant,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  LogEntry updateTranscript(String nextTranscript) {
    final normalizedTranscript = nextTranscript.trim();
    return copyWith(
      task: normalizedTranscript,
      transcript: normalizedTranscript,
      flavor: LogEntryFlavor.voice,
      updatedAt: DateTime.now(),
    );
  }

  bool get isSessionEvent => entryType != LogEntryType.manual;

  bool get isVoiceEntry => flavor == LogEntryFlavor.voice;

  bool get isLegacyEntry => !isVoiceEntry;

  bool get isEditable => isVoiceEntry;

  bool get isArchived => archivedAt != null;

  bool get isInTrash => deletedAt != null;

  bool get isActive => !isArchived && !isInTrash;

  String get transcriptText {
    final voiceTranscript = _normalizeText(transcript);
    if (voiceTranscript != null) {
      return voiceTranscript;
    }
    return legacySummary;
  }

  String get previewText {
    final text = transcriptText.replaceAll('\n', ' ').trim();
    if (text.length <= 96) {
      return text;
    }
    return '${text.substring(0, 93)}...';
  }

  String get legacySummary {
    final parts = <String>[task.trim()];
    if (_normalizeText(problem) case final problemText?) {
      parts.add('Problem: $problemText');
    }
    if (_normalizeText(solutionTried) case final solutionText?) {
      parts.add('Tried: $solutionText');
    }
    if (_normalizeText(notes) case final notesText?) {
      parts.add('Notes: $notesText');
    }
    if (!isSessionEvent) {
      parts.add('Result: ${result.label}');
    }
    return parts.where((part) => part.trim().isNotEmpty).join('\n');
  }

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
