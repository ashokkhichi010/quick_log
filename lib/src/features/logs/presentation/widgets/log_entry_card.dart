import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatters.dart';
import '../../../../core/widgets/soft_ui.dart';
import '../../domain/entry_result.dart';
import '../../domain/log_entry.dart';
import '../../domain/log_entry_type.dart';

enum EntryMenuAction { edit, duplicate, delete }

class LogEntryCard extends StatelessWidget {
  const LogEntryCard({
    super.key,
    required this.entry,
    required this.categoryName,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggleImportant,
  });

  final LogEntry entry;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onToggleImportant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = switch (entry.entryType) {
      LogEntryType.checkIn => Colors.blue.shade600,
      LogEntryType.checkOut => Colors.deepOrange.shade500,
      LogEntryType.manual => switch (entry.result) {
        EntryResult.worked => Colors.green.shade600,
        EntryResult.notWorked => Colors.red.shade400,
        EntryResult.partial => Colors.orange.shade500,
      },
    };
    final canInteract = entry.isEditable;
    final content = GestureDetector(
      onTap: canInteract ? onEdit : null,
      child: SoftSurface(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CapsuleLabel(
                            icon: Icons.schedule_rounded,
                            text: formatEntryTime(entry.timestamp),
                          ),
                          _CapsuleLabel(
                            icon: switch (entry.entryType) {
                              LogEntryType.checkIn => Icons.login_rounded,
                              LogEntryType.checkOut => Icons.logout_rounded,
                              LogEntryType.manual => Icons.sell_outlined,
                            },
                            text: entry.isSessionEvent
                                ? entry.entryType.label
                                : categoryName,
                          ),
                          _CapsuleLabel(
                            icon: entry.isImportant
                                ? Icons.star_rounded
                                : entry.isSessionEvent
                                ? Icons.event_available_rounded
                                : Icons.track_changes_rounded,
                            text: entry.isImportant
                                ? 'Important'
                                : entry.isSessionEvent
                                ? entry.entryType.label
                                : entry.result.label,
                            accentColor: accentColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(entry.task, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                if (canInteract)
                  PopupMenuButton<EntryMenuAction>(
                    onSelected: (action) {
                      switch (action) {
                        case EntryMenuAction.edit:
                          onEdit();
                        case EntryMenuAction.duplicate:
                          onDuplicate();
                        case EntryMenuAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: EntryMenuAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: EntryMenuAction.duplicate,
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(
                        value: EntryMenuAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            if (entry.problem != null) ...[
              const SizedBox(height: 14),
              _InsightRow(label: 'Problem', value: entry.problem!),
            ],
            if (entry.solutionTried != null) ...[
              const SizedBox(height: 10),
              _InsightRow(label: 'Solution', value: entry.solutionTried!),
            ],
            if (entry.notes != null) ...[
              const SizedBox(height: 10),
              _InsightRow(label: 'Notes', value: entry.notes!),
            ],
          ],
        ),
      ),
    );

    if (!canInteract) {
      return content;
    }

    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onToggleImportant();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              entry.isImportant
                  ? Icons.star_border_rounded
                  : Icons.star_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              entry.isImportant ? 'Remove important' : 'Mark important',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      child: content,
    );
  }
}

class _CapsuleLabel extends StatelessWidget {
  const _CapsuleLabel({
    required this.icon,
    required this.text,
    this.accentColor,
  });

  final IconData icon;
  final String text;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = accentColor ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
