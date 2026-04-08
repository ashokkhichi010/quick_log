import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entry_result.dart';
import '../../domain/log_entry.dart';
import '../../domain/repositories/entries_repository.dart';

class EntriesState {
  const EntriesState({
    required this.entries,
    required this.searchQuery,
    required this.selectedCategoryId,
    required this.selectedResult,
    required this.importantOnly,
    required this.isLoading,
  });

  const EntriesState.initial()
    : entries = const [],
      searchQuery = '',
      selectedCategoryId = null,
      selectedResult = null,
      importantOnly = false,
      isLoading = true;

  final List<LogEntry> entries;
  final String searchQuery;
  final String? selectedCategoryId;
  final EntryResult? selectedResult;
  final bool importantOnly;
  final bool isLoading;

  List<LogEntry> get visibleEntries {
    final query = searchQuery.trim().toLowerCase();
    return entries.where((entry) {
      final matchesSearch =
          query.isEmpty ||
          entry.task.toLowerCase().contains(query) ||
          (entry.problem?.toLowerCase().contains(query) ?? false) ||
          (entry.solutionTried?.toLowerCase().contains(query) ?? false) ||
          (entry.notes?.toLowerCase().contains(query) ?? false);
      final matchesCategory =
          selectedCategoryId == null || entry.categoryId == selectedCategoryId;
      final matchesResult =
          selectedResult == null || entry.result == selectedResult;
      final matchesImportance = !importantOnly || entry.isImportant;

      return matchesSearch &&
          matchesCategory &&
          matchesResult &&
          matchesImportance;
    }).toList()..sort(
      (left, right) => right.timestamp.compareTo(left.timestamp),
    );
  }

  EntriesState copyWith({
    List<LogEntry>? entries,
    String? searchQuery,
    Object? selectedCategoryId = _selectedUnset,
    Object? selectedResult = _selectedUnset,
    bool? importantOnly,
    bool? isLoading,
  }) {
    return EntriesState(
      entries: entries ?? this.entries,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: identical(selectedCategoryId, _selectedUnset)
          ? this.selectedCategoryId
          : selectedCategoryId as String?,
      selectedResult: identical(selectedResult, _selectedUnset)
          ? this.selectedResult
          : selectedResult as EntryResult?,
      importantOnly: importantOnly ?? this.importantOnly,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const _selectedUnset = Object();
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

  Future<void> createEntry(LogEntryDraft draft) async {
    final entry = LogEntry.create(id: _uuid.v4(), draft: draft);
    await _repository.saveEntry(entry);
    state = state.copyWith(entries: _mergeEntries(entry));
  }

  Future<void> updateEntry({
    required LogEntry existingEntry,
    required LogEntryDraft draft,
  }) async {
    final updated = existingEntry.applyDraft(draft);
    await _repository.saveEntry(updated);
    state = state.copyWith(entries: _mergeEntries(updated));
  }

  Future<void> deleteEntry(LogEntry entry) async {
    await _repository.deleteEntry(entry.id);
    state = state.copyWith(
      entries: state.entries.where((item) => item.id != entry.id).toList(),
    );
  }

  Future<void> restoreEntry(LogEntry entry) async {
    await _repository.saveEntry(entry);
    state = state.copyWith(entries: _mergeEntries(entry));
  }

  Future<void> duplicateEntry(LogEntry entry) async {
    final now = DateTime.now();
    final duplicate = entry.copyWith(
      id: _uuid.v4(),
      timestamp: now,
      createdAt: now,
      updatedAt: now,
      isImportant: false,
    );
    await _repository.saveEntry(duplicate);
    state = state.copyWith(entries: _mergeEntries(duplicate));
  }

  Future<void> toggleImportant(LogEntry entry) async {
    final updated = entry.copyWith(
      isImportant: !entry.isImportant,
      updatedAt: DateTime.now(),
    );
    await _repository.saveEntry(updated);
    state = state.copyWith(entries: _mergeEntries(updated));
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void setResultFilter(EntryResult? result) {
    state = state.copyWith(selectedResult: result);
  }

  void toggleImportantFilter() {
    state = state.copyWith(importantOnly: !state.importantOnly);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedCategoryId: null,
      selectedResult: null,
      importantOnly: false,
    );
  }

  List<LogEntry> _mergeEntries(LogEntry entry) {
    final updatedEntries = [
      entry,
      ...state.entries.where((item) => item.id != entry.id),
    ];
    updatedEntries.sort(
      (left, right) => right.timestamp.compareTo(left.timestamp),
    );
    return updatedEntries;
  }
}
