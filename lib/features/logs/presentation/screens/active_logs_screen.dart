import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../domain/log_entry.dart';
import '../../shared/widgets/logs_empty_state.dart';
import '../../shared/widgets/logs_list_widget.dart';
import '../../shared/widgets/transcript_editor_dialog.dart';

class ActiveLogsScreen extends ConsumerStatefulWidget {
  const ActiveLogsScreen({super.key});

  @override
  ConsumerState<ActiveLogsScreen> createState() => _ActiveLogsScreenState();
}

class _ActiveLogsScreenState extends ConsumerState<ActiveLogsScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesState = ref.watch(entriesControllerProvider);
    final settingsState = ref.watch(appSettingsControllerProvider);
    final isLoading = entriesState.isLoading || settingsState.isLoading;
    final visibleEntries = entriesState.entries.where((entry) {
      return entry.isActive && (!entriesState.importantOnly || entry.isImportant);
    }).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: LogsListWidget(
              entries: visibleEntries,
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              emptyState: const LogsEmptyState(
                icon: Icons.mic_none_rounded,
                title: 'No logs yet',
                subtitle: 'Use Record below to capture work in a few seconds.',
              ),
              onEdit: _editVoiceEntry,
              onArchive: _archiveEntry,
              onDelete: _deleteEntry,
              onToggleImportant: (entry) {
                ref.read(entriesControllerProvider.notifier).toggleImportant(entry);
              },
            ),
          );
  }

  Future<void> _editVoiceEntry(LogEntry entry) async {
    if (!entry.isVoiceEntry) {
      return;
    }

    final updatedTranscript = await showTranscriptEditorDialog(
      context: context,
      initialValue: entry.transcriptText,
    );

    if (updatedTranscript == null || updatedTranscript.trim().isEmpty) {
      return;
    }

    await ref.read(entriesControllerProvider.notifier).updateTranscriptEntry(
      existingEntry: entry,
      transcript: updatedTranscript,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transcript updated.')));
  }

  Future<void> _deleteEntry(LogEntry entry) async {
    await ref.read(entriesControllerProvider.notifier).deleteEntry(entry);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry moved to trash. Auto-deletes in 30 days.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(entriesControllerProvider.notifier).restoreEntry(entry);
          },
        ),
      ),
    );
  }

  Future<void> _archiveEntry(LogEntry entry) async {
    await ref.read(entriesControllerProvider.notifier).archiveEntry(entry);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry archived.')));
  }
}
