import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/constants/reminder_intervals.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/export_format.dart';
import '../../logs/domain/category.dart';
import '../../logs/domain/log_entry.dart';
import '../domain/app_settings.dart';
import 'controllers/app_settings_controller.dart';
import 'widgets/category_management_section.dart';
import 'widgets/setting_section.dart';
import 'widgets/setting_tile.dart';

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
    final entriesState = ref.watch(entriesControllerProvider);
    final categoriesState = ref.watch(categoriesControllerProvider);
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
                SettingSection(
                  title: 'Reminders',
                  description: 'Prompt quick work updates through the day.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: settings.remindersEnabled,
                        title: const Text('Enable reminders'),
                        subtitle: const Text('Keep the nudge flow lightweight.'),
                        onChanged: _toggleReminders,
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
                          hintText: 'Capture your progress',
                        ),
                      ),
                    ],
                  ),
                ),
                SettingSection(
                  title: 'Theme',
                  description: 'Choose the workspace look that fits your day.',
                  child: SegmentedButton<AppThemeMode>(
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
                ),
                SettingSection(
                  title: 'Log Management',
                  description: 'Review archived and deleted items separately.',
                  child: Column(
                    children: [
                      SettingTile(
                        title: 'Archived logs',
                        subtitle: 'View, restore, or permanently remove archived logs.',
                        leading: const Icon(Icons.archive_outlined),
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.archivedLogs);
                        },
                      ),
                      const Divider(height: 10),
                      SettingTile(
                        title: 'Deleted logs',
                        subtitle: 'Restore or clear trashed logs before auto-delete.',
                        leading: const Icon(Icons.delete_outline_rounded),
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.deletedLogs);
                        },
                      ),
                    ],
                  ),
                ),
                const CategoryManagementSection(),
                SettingSection(
                  title: 'Export Data',
                  description:
                      'Save a local file and open the Android share sheet immediately.',
                  margin: EdgeInsets.zero,
                  child: Wrap(
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
        const SnackBar(
          content: Text('Notification or exact alarm permission was denied.'),
        ),
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
      ref.read(appSettingsControllerProvider.notifier).setReminderMessage(value);
    });
  }

  Future<void> _export({
    required ExportFormat format,
    required List<LogEntry> entries,
    required List<Category> categories,
  }) async {
    final result = await ref.read(exportServiceProvider).exportEntries(
      format: format,
      entries: entries,
      categories: categories,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported ${result.fileName}.')));
  }
}
