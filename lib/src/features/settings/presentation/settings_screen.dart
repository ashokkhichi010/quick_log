import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/constants/reminder_intervals.dart';
import '../../../core/models/export_format.dart';
import '../../../core/widgets/soft_ui.dart';
import '../../logs/domain/category.dart';
import '../../logs/domain/log_entry.dart';
import '../domain/app_settings.dart';
import 'controllers/app_settings_controller.dart';
import 'controllers/categories_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _reminderMessageController;
  Timer? _messageDebounce;
  bool _seededReminderMessage = false;

  @override
  void initState() {
    super.initState();
    _reminderMessageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageDebounce?.cancel();
    _reminderMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(appSettingsControllerProvider);
    final categoriesState = ref.watch(categoriesControllerProvider);
    final entriesState = ref.watch(entriesControllerProvider);
    final settings = settingsState.settings;

    if (!_seededReminderMessage && !settingsState.isLoading) {
      _reminderMessageController.text = settings.reminderMessage;
      _seededReminderMessage = true;
    }

    final isLoading = settingsState.isLoading || categoriesState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SoftSurface(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Reminders'),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: settings.remindersEnabled,
                        title: const Text('Enable reminders'),
                        subtitle: const Text(
                          'Prompt quick work updates through the day.',
                        ),
                        onChanged: (enabled) => _toggleReminders(enabled),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: settings.reminderIntervalMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Reminder interval',
                        ),
                        items: [
                          for (final option in reminderIntervalOptions)
                            DropdownMenuItem<int>(
                              value: option.minutes,
                              child: Text(option.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(appSettingsControllerProvider.notifier)
                              .setReminderInterval(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reminderMessageController,
                        onChanged: _debounceReminderMessage,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Reminder text',
                          hintText: 'What are you working on?',
                        ),
                      ),
                    ],
                  ),
                ),
                SoftSurface(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Theme'),
                      const SizedBox(height: 12),
                      SegmentedButton<AppThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_rounded),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selection) {
                          ref
                              .read(appSettingsControllerProvider.notifier)
                              .setThemeMode(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
                SoftSurface(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        title: 'Categories',
                        trailing: TextButton.icon(
                          onPressed: _addCategory,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleting a category moves old entries to Other.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final category in categoriesState.categories)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(category.name),
                          subtitle: Text(
                            category.isDefault
                                ? 'Default category'
                                : 'Custom category',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editCategory(category),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed:
                                    category.id == Category.fallbackCategoryId
                                    ? null
                                    : () => _deleteCategory(category),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SoftSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Export Data'),
                      const SizedBox(height: 12),
                      Text(
                        'Save a file locally and open the Android share sheet immediately.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _export(
                              format: ExportFormat.csv,
                              entries: entriesState.entries,
                              categories: categoriesState.categories,
                            ),
                            icon: const Icon(Icons.table_chart_outlined),
                            label: const Text('Export CSV'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _export(
                              format: ExportFormat.json,
                              entries: entriesState.entries,
                              categories: categoriesState.categories,
                            ),
                            icon: const Icon(Icons.data_object_rounded),
                            label: const Text('Export JSON'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _toggleReminders(bool enabled) async {
    final result = await ref
        .read(appSettingsControllerProvider.notifier)
        .setRemindersEnabled(enabled);

    if (!mounted) {
      return;
    }

    if (result == ReminderToggleResult.permissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission was denied.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? 'Reminders enabled.' : 'Reminders turned off.'),
      ),
    );
  }

  void _debounceReminderMessage(String value) {
    _messageDebounce?.cancel();
    _messageDebounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(appSettingsControllerProvider.notifier)
          .setReminderMessage(value);
    });
  }

  Future<void> _addCategory() async {
    final name = await _showCategoryDialog();
    if (name == null) {
      return;
    }

    try {
      await ref.read(categoriesControllerProvider.notifier).addCategory(name);
    } on CategoryException catch (error) {
      _showMessage(error.message);
      return;
    }

    _showMessage('Category added.');
  }

  Future<void> _editCategory(Category category) async {
    final name = await _showCategoryDialog(initialValue: category.name);
    if (name == null) {
      return;
    }

    try {
      await ref
          .read(categoriesControllerProvider.notifier)
          .renameCategory(category, name);
    } on CategoryException catch (error) {
      _showMessage(error.message);
      return;
    }

    _showMessage('Category updated.');
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      await ref
          .read(categoriesControllerProvider.notifier)
          .deleteCategory(category);
      await ref.read(entriesControllerProvider.notifier).loadEntries();
    } on CategoryException catch (error) {
      _showMessage(error.message);
      return;
    }

    _showMessage('Category deleted. Existing entries moved to Other.');
  }

  Future<void> _export({
    required ExportFormat format,
    required List<LogEntry> entries,
    required List<Category> categories,
  }) async {
    final result = await ref
        .read(exportServiceProvider)
        .exportEntries(
          format: format,
          entries: entries,
          categories: categories,
        );

    if (!mounted) {
      return;
    }

    _showMessage('Exported ${result.fileName}.');
  }

  Future<String?> _showCategoryDialog({String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialValue == null ? 'Add category' : 'Edit category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
