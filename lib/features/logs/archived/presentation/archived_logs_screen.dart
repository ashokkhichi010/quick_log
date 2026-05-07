import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../domain/log_entry.dart';
import '../../shared/widgets/logs_empty_state.dart';
import '../../shared/widgets/logs_list_widget.dart';
import '../../shared/widgets/transcript_editor_dialog.dart';

class ArchivedLogsScreen extends ConsumerStatefulWidget {
  const ArchivedLogsScreen({super.key});

  @override
  ConsumerState<ArchivedLogsScreen> createState() => _ArchivedLogsScreenState();
}

class _ArchivedLogsScreenState extends ConsumerState<ArchivedLogsScreen> {
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
    final state = ref.watch(entriesControllerProvider);
    final archivedEntries = state.entries.where((entry) => entry.isArchived).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Archived Logs')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LogsListWidget(
                entries: archivedEntries,
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                searchHintText: 'Search archived logs',
                emptyState: const LogsEmptyState(
                  icon: Icons.archive_outlined,
                  title: 'No archived logs',
                  subtitle: 'Archive logs from home to keep the timeline tidy.',
                ),
                onEdit: _editVoiceEntry,
                onRestore: _restoreEntry,
                onPermanentlyDelete: _permanentlyDeleteEntry,
                onToggleImportant: (entry) {
                  ref.read(entriesControllerProvider.notifier).toggleImportant(entry);
                },
              ),
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
      title: 'Edit archived transcript',
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
    ).showSnackBar(const SnackBar(content: Text('Archived log updated.')));
  }

  Future<void> _restoreEntry(LogEntry entry) async {
    await ref.read(entriesControllerProvider.notifier).restoreEntry(entry);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry restored.')));
  }

  Future<void> _permanentlyDeleteEntry(LogEntry entry) async {
    final confirmed = await _confirmPermanentDelete(context);
    if (!confirmed) {
      return;
    }

    await ref.read(entriesControllerProvider.notifier).permanentlyDeleteEntry(entry);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Archived log deleted.')));
  }
}

Future<bool> _confirmPermanentDelete(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text('This log will be removed and cannot be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
