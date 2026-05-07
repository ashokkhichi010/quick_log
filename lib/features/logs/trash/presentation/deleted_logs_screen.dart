import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../domain/log_entry.dart';
import '../../shared/widgets/logs_empty_state.dart';
import '../../shared/widgets/logs_list_widget.dart';

class DeletedLogsScreen extends ConsumerStatefulWidget {
  const DeletedLogsScreen({super.key});

  @override
  ConsumerState<DeletedLogsScreen> createState() => _DeletedLogsScreenState();
}

class _DeletedLogsScreenState extends ConsumerState<DeletedLogsScreen> {
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
    final trashedEntries = state.entries.where((entry) => entry.isInTrash).toList();
    trashedEntries.sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Logs'),
        actions: [
          if (trashedEntries.isNotEmpty)
            TextButton(
              onPressed: _clearTrash,
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LogsListWidget(
                entries: trashedEntries,
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                searchHintText: 'Search deleted logs',
                emptyState: const LogsEmptyState(
                  icon: Icons.delete_outline_rounded,
                  title: 'Trash is empty',
                  subtitle: 'Deleted logs stay here until you restore or remove them.',
                ),
                onRestore: _restoreEntry,
                onPermanentlyDelete: _permanentlyDeleteEntry,
                onToggleImportant: (entry) {
                  ref.read(entriesControllerProvider.notifier).toggleImportant(entry);
                },
              ),
            ),
    );
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
    if (confirmed != true) {
      return;
    }

    await ref.read(entriesControllerProvider.notifier).permanentlyDeleteEntry(entry);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry deleted permanently.')));
  }

  Future<void> _clearTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear trash?'),
          content: const Text(
            'All deleted logs will be removed permanently and cannot be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(entriesControllerProvider.notifier).clearTrash();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trash cleared.')));
  }
}
