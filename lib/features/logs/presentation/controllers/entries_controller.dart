import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/log_entry.dart';
import '../../domain/repositories/entries_repository.dart';

enum LogsVisibilityFilter {
  active,
  archived,
  trash,
}

class EntriesState {
  const EntriesState({
    required this.entries,
    required this.searchQuery,
    required this.importantOnly,
    required this.visibility,
    required this.isLoading,
  });

  const EntriesState.initial()
    : entries = const [],
      searchQuery = '',
      importantOnly = false,
      visibility = LogsVisibilityFilter.active,
      isLoading = true;

  final List<LogEntry> entries;
  final String searchQuery;
  final bool importantOnly;
  final LogsVisibilityFilter visibility;
  final bool isLoading;

  List<LogEntry> get visibleEntries {
    final query = searchQuery.trim().toLowerCase();
    return entries.where((entry) {
      final matchesVisibility = switch (visibility) {
        LogsVisibilityFilter.active => entry.isActive,
        LogsVisibilityFilter.archived => entry.isArchived,
        LogsVisibilityFilter.trash => entry.isInTrash,
      };

      if (!matchesVisibility) return false;
      final matchesSearch =
          query.isEmpty ||
          entry.transcriptText.toLowerCase().contains(query);
      final matchesImportance = !importantOnly || entry.isImportant;

      return matchesSearch && matchesImportance;
    }).toList()..sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
  }

  EntriesState copyWith({
    List<LogEntry>? entries,
    String? searchQuery,
    bool? importantOnly,
    LogsVisibilityFilter? visibility,
    bool? isLoading,
  }) {
    return EntriesState(
      entries: entries ?? this.entries,
      searchQuery: searchQuery ?? this.searchQuery,
      importantOnly: importantOnly ?? this.importantOnly,
      visibility: visibility ?? this.visibility,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class EntriesController extends StateNotifier<EntriesState> {
  EntriesController({required EntriesRepository repository, required Uuid uuid})
    : _repository = repository,
      _uuid = uuid,
      super(const EntriesState.initial()) {
    loadEntries();
  }

  final EntriesRepository _repository;
  final Uuid _uuid;

  Future<void> loadEntries() async {
    final entries = await _repository.fetchEntries();
    state = state.copyWith(entries: entries, isLoading: false);
  }

  Future<void> createVoiceEntry(String transcript) async {
    final entry = LogEntry.voice(id: _uuid.v4(), transcript: transcript);
    await _repository.saveEntry(entry);
    state = state.copyWith(entries: _mergeEntries(entry));
  }

  Future<void> updateTranscriptEntry({
    required LogEntry existingEntry,
    required String transcript,
  }) async {
    final updated = existingEntry.updateTranscript(transcript);
    await _repository.saveEntry(updated);
    state = state.copyWith(entries: _mergeEntries(updated));
  }

  Future<void> deleteEntry(LogEntry entry) async {
    final trashed = entry.copyWith(
      deletedAt: DateTime.now(),
      archivedAt: null,
      updatedAt: DateTime.now(),
    );
    await _repository.saveEntry(trashed);
    state = state.copyWith(entries: _mergeEntries(trashed));
  }

  Future<void> restoreEntry(LogEntry entry) async {
    final restored = entry.copyWith(
      deletedAt: null,
      archivedAt: null,
      updatedAt: DateTime.now(),
    );
    await _repository.saveEntry(restored);
    state = state.copyWith(entries: _mergeEntries(restored));
  }

  Future<void> archiveEntry(LogEntry entry) async {
    final archived = entry.copyWith(
      archivedAt: DateTime.now(),
      deletedAt: null,
      updatedAt: DateTime.now(),
    );
    await _repository.saveEntry(archived);
    state = state.copyWith(entries: _mergeEntries(archived));
  }

  Future<void> toggleImportant(LogEntry entry) async {
    final updated = entry.copyWith(
      isImportant: !entry.isImportant,
      updatedAt: DateTime.now(),
    );
    await _repository.saveEntry(updated);
    state = state.copyWith(entries: _mergeEntries(updated));
  }

  Future<void> permanentlyDeleteEntry(LogEntry entry) async {
    await _repository.permanentlyDeleteEntry(entry.id);
    state = state.copyWith(
      entries: state.entries.where((item) => item.id != entry.id).toList(),
    );
  }

  Future<void> clearTrash() async {
    final trashedEntries = state.entries.where((item) => item.isInTrash).toList();
    for (final entry in trashedEntries) {
      await _repository.permanentlyDeleteEntry(entry.id);
    }

    state = state.copyWith(
      entries: state.entries.where((item) => !item.isInTrash).toList(),
    );
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void toggleImportantFilter() {
    state = state.copyWith(importantOnly: !state.importantOnly);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      importantOnly: false,
      visibility: LogsVisibilityFilter.active,
    );
  }

  void setVisibilityFilter(LogsVisibilityFilter filter) {
    if (filter == state.visibility) return;
    state = state.copyWith(visibility: filter);
  }

  List<LogEntry> _mergeEntries(LogEntry entry) {
    final updatedEntries = [
      entry,
      ...state.entries.where((item) => item.id != entry.id),
    ];
    updatedEntries.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
    return updatedEntries;
  }
}
