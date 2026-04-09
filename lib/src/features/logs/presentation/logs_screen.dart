import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_routes.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/widgets/soft_ui.dart';
import '../../settings/presentation/controllers/app_settings_controller.dart';
import '../domain/category.dart';
import '../domain/entry_result.dart';
import '../domain/log_entry.dart';
import 'widgets/entry_editor_sheet.dart';
import 'widgets/log_entry_card.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesState = ref.watch(entriesControllerProvider);
    final categoriesState = ref.watch(categoriesControllerProvider);
    final settingsState = ref.watch(appSettingsControllerProvider);
    final categories = categoriesState.categories;
    final appSettings = settingsState.settings;

    if (_searchController.text != entriesState.searchQuery) {
      _searchController.value = TextEditingValue(
        text: entriesState.searchQuery,
        selection: TextSelection.collapsed(
          offset: entriesState.searchQuery.length,
        ),
      );
    }

    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final groupedEntries = _groupEntries(entriesState.visibleEntries);
    final isLoading =
        entriesState.isLoading ||
        categoriesState.isLoading ||
        settingsState.isLoading;
    final showFilters = _searchFocusNode.hasFocus;

    if (!isLoading && !appSettings.isCheckedIn && !_isCheckingOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.checkIn, (route) => false);
      });

      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Log'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              if (_isCheckingOut) {
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final settingsController = ref.read(
                appSettingsControllerProvider.notifier,
              );
              final entriesController = ref.read(
                entriesControllerProvider.notifier,
              );

              setState(() {
                _isCheckingOut = true;
              });

              await settingsController.checkOut();
              await entriesController.loadEntries();
              if (!mounted) {
                return;
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('Checked out successfully.')),
              );
              navigator.pushNamedAndRemoveUntil(
                AppRoutes.checkIn,
                (route) => false,
              );
              if (mounted) {
                setState(() {
                  _isCheckingOut = false;
                });
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Checkout'),
          ),
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SoftSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SessionBanner(
                            checkedInAt: appSettings.activeSessionStartedAt,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: ref
                                .read(entriesControllerProvider.notifier)
                                .setSearchQuery,
                            onTapOutside: (_) => _searchFocusNode.unfocus(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: entriesState.searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(
                                              entriesControllerProvider
                                                  .notifier,
                                            )
                                            .setSearchQuery('');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              hintText: 'Search tasks, problems, or notes',
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: showFilters
                                ? Padding(
                                    key: const ValueKey('filter-strip-open'),
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _FilterStrip(
                                      categories: categories,
                                      selectedCategoryId:
                                          entriesState.selectedCategoryId,
                                      selectedResult:
                                          entriesState.selectedResult,
                                      importantOnly: entriesState.importantOnly,
                                      onCategorySelected: ref
                                          .read(
                                            entriesControllerProvider.notifier,
                                          )
                                          .setCategoryFilter,
                                      onResultSelected: ref
                                          .read(
                                            entriesControllerProvider.notifier,
                                          )
                                          .setResultFilter,
                                      onImportantToggle: ref
                                          .read(
                                            entriesControllerProvider.notifier,
                                          )
                                          .toggleImportantFilter,
                                      onClear: () {
                                        _searchController.clear();
                                        ref
                                            .read(
                                              entriesControllerProvider
                                                  .notifier,
                                            )
                                            .clearFilters();
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('filter-strip-closed'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: groupedEntries.isEmpty
                        ? const _EmptyTimeline()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            children: [
                              for (final section in groupedEntries.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    formatTimelineHeader(section.key),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                for (final entry in section.value)
                                  LogEntryCard(
                                    entry: entry,
                                    categoryName:
                                        categoryNames[entry.categoryId] ??
                                        'Unknown',
                                    onEdit: () => _openEntryEditor(
                                      categories: categories,
                                      settingsState: settingsState,
                                      entry: entry,
                                    ),
                                    onDuplicate: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      await ref
                                          .read(
                                            entriesControllerProvider.notifier,
                                          )
                                          .duplicateEntry(entry);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Entry duplicated.'),
                                        ),
                                      );
                                    },
                                    onDelete: () => _deleteEntry(entry),
                                    onToggleImportant: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      await ref
                                          .read(
                                            entriesControllerProvider.notifier,
                                          )
                                          .toggleImportant(entry);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            entry.isImportant
                                                ? 'Entry removed from important.'
                                                : 'Entry marked important.',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading
            ? null
            : () => _openEntryEditor(
                categories: categories,
                settingsState: settingsState,
              ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick Add Entry'),
      ),
    );
  }

  Future<void> _openEntryEditor({
    required List<Category> categories,
    required AppSettingsState settingsState,
    LogEntry? entry,
  }) async {
    if (categories.isEmpty) {
      return;
    }

    final categoryExists = categories.any(
      (item) => item.id == settingsState.settings.lastUsedCategoryId,
    );
    final initialCategoryId =
        entry?.categoryId ??
        (categoryExists
            ? settingsState.settings.lastUsedCategoryId
            : categories.first.id);

    final draft = await showEntryEditorSheet(
      context: context,
      categories: categories,
      initialCategoryId: initialCategoryId,
      initialResult: entry?.result ?? settingsState.settings.lastUsedResult,
      existingEntry: entry,
    );

    if (draft == null) {
      return;
    }

    if (entry == null) {
      await ref.read(entriesControllerProvider.notifier).createEntry(draft);
    } else {
      await ref
          .read(entriesControllerProvider.notifier)
          .updateEntry(existingEntry: entry, draft: draft);
    }

    await ref
        .read(appSettingsControllerProvider.notifier)
        .rememberLastUsed(categoryId: draft.categoryId, result: draft.result);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(entry == null ? 'Entry saved.' : 'Entry updated.'),
      ),
    );
  }

  Future<void> _deleteEntry(LogEntry entry) async {
    await ref.read(entriesControllerProvider.notifier).deleteEntry(entry);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(entriesControllerProvider.notifier).restoreEntry(entry);
          },
        ),
      ),
    );
  }

  LinkedHashMap<DateTime, List<LogEntry>> _groupEntries(
    List<LogEntry> entries,
  ) {
    final grouped = <DateTime, List<LogEntry>>{};
    for (final entry in entries) {
      final key = truncateToHour(entry.timestamp);
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return LinkedHashMap<DateTime, List<LogEntry>>.from(grouped);
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedResult,
    required this.importantOnly,
    required this.onCategorySelected,
    required this.onResultSelected,
    required this.onImportantToggle,
    required this.onClear,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final EntryResult? selectedResult;
  final bool importantOnly;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<EntryResult?> onResultSelected;
  final VoidCallback onImportantToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        selectedCategoryId != null || selectedResult != null || importantOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterChip(
                label: const Text('All results'),
                selected: selectedResult == null,
                onSelected: (_) => onResultSelected(null),
              ),
              const SizedBox(width: 8),
              for (final result in EntryResult.values) ...[
                FilterChip(
                  label: Text(result.label),
                  selected: selectedResult == result,
                  onSelected: (_) => onResultSelected(result),
                ),
                const SizedBox(width: 8),
              ],
              FilterChip(
                label: const Text('Important'),
                selected: importantOnly,
                onSelected: (_) => onImportantToggle(),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                ActionChip(label: const Text('Clear'), onPressed: onClear),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterChip(
                label: const Text('All categories'),
                selected: selectedCategoryId == null,
                onSelected: (_) => onCategorySelected(null),
              ),
              const SizedBox(width: 8),
              for (final category in categories) ...[
                FilterChip(
                  label: Text(category.name),
                  selected: selectedCategoryId == category.id,
                  onSelected: (_) => onCategorySelected(category.id),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.checkedInAt});

  final DateTime? checkedInAt;

  @override
  Widget build(BuildContext context) {
    final startedAt = checkedInAt;
    final label = startedAt == null
        ? 'Session active'
        : 'Checked in at ${DateFormat('h:mm a').format(startedAt)}';

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.green.shade500,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SoftSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'No logs yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Quick Add Entry and capture what you are working on in a few seconds.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
