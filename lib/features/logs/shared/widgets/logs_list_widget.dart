import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/log_entry.dart';
import 'log_card.dart';
import 'logs_empty_state.dart';
import 'logs_search_bar.dart';
import 'logs_section_header.dart';

class LogsListWidget extends StatelessWidget {
  const LogsListWidget({
    super.key,
    required this.entries,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.emptyState,
    required this.onToggleImportant,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onRestore,
    this.onPermanentlyDelete,
    this.header,
    this.searchHintText = 'Search logs',
    this.itemBuilder,
  });

  final List<LogEntry> entries;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Widget emptyState;
  final void Function(LogEntry entry) onToggleImportant;
  final void Function(LogEntry entry)? onEdit;
  final void Function(LogEntry entry)? onArchive;
  final void Function(LogEntry entry)? onDelete;
  final void Function(LogEntry entry)? onRestore;
  final void Function(LogEntry entry)? onPermanentlyDelete;
  final Widget? header;
  final String searchHintText;
  final Widget Function(BuildContext context, LogEntry entry)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filterEntries(entries, searchQuery);
    final groupedEntries = _groupEntries(filteredEntries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: 16),
        ],
        LogsSearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: searchHintText,
        ),
        const SizedBox(height: 16),
        if (filteredEntries.isEmpty)
          searchQuery.trim().isEmpty
              ? emptyState
              : const LogsEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching logs',
                  subtitle: 'Try a different search phrase or clear the filter.',
                )
        else
          ...groupedEntries.entries.expand((section) sync* {
            yield LogsSectionHeader(label: _formatDayHeader(section.key));
            for (final entry in section.value) {
              yield itemBuilder?.call(context, entry) ??
                  LogCard(
                    entry: entry,
                    onEdit: onEdit == null ? null : () => onEdit!(entry),
                    onArchive: onArchive == null ? null : () => onArchive!(entry),
                    onDelete: onDelete == null ? null : () => onDelete!(entry),
                    onRestore: onRestore == null ? null : () => onRestore!(entry),
                    onPermanentlyDelete: onPermanentlyDelete == null
                        ? null
                        : () => onPermanentlyDelete!(entry),
                    onToggleImportant: () => onToggleImportant(entry),
                  );
            }
          }),
      ],
    );
  }

  List<LogEntry> _filterEntries(List<LogEntry> source, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return source;
    }

    return source.where((entry) {
      return entry.transcriptText.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  LinkedHashMap<DateTime, List<LogEntry>> _groupEntries(List<LogEntry> source) {
    final grouped = <DateTime, List<LogEntry>>{};
    for (final entry in source) {
      final key = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return LinkedHashMap<DateTime, List<LogEntry>>.from(grouped);
  }

  String _formatDayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) {
      return 'Today';
    }
    if (day == yesterday) {
      return 'Yesterday';
    }
    return DateFormat('d MMM yyyy').format(day);
  }
}
