import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatters.dart';
import '../../../../core/widgets/soft_ui.dart';
import '../../domain/log_entry.dart';
import '../../domain/log_entry_flavor.dart';

enum _LogCardAction {
  edit,
  restore,
  permanentlyDelete,
}

class LogCard extends StatelessWidget {
  const LogCard({
    super.key,
    required this.entry,
    required this.onToggleImportant,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onRestore,
    this.onPermanentlyDelete,
  });

  final LogEntry entry;
  final VoidCallback onToggleImportant;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentlyDelete;

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onEdit,
      onLongPress: onToggleImportant,
      child: SoftSurface(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(
                  icon: Icons.schedule_rounded,
                  text: formatEntryTime(entry.createdAt),
                ),
                const SizedBox(width: 8),
                _Pill(
                  icon: entry.isVoiceEntry
                      ? Icons.mic_rounded
                      : Icons.history_rounded,
                  text: entry.flavor.label,
                ),
                if (entry.isArchived) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.archive_outlined,
                    text: 'Archived',
                    tint: Colors.blue.shade300,
                  ),
                ] else if (entry.isInTrash) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.delete_outline_rounded,
                    text: 'Trash',
                    tint: Colors.red.shade300,
                  ),
                ],
                if (entry.isImportant) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.star_rounded,
                    text: 'Important',
                    tint: Theme.of(context).colorScheme.primary,
                  ),
                ],
                const Spacer(),
                if (_hasMenuActions)
                  PopupMenuButton<_LogCardAction>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      switch (value) {
                        case _LogCardAction.edit:
                          onEdit?.call();
                        case _LogCardAction.restore:
                          onRestore?.call();
                        case _LogCardAction.permanentlyDelete:
                          onPermanentlyDelete?.call();
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: _LogCardAction.edit,
                            child: Text('Edit transcript'),
                          ),
                        if (onRestore != null)
                          const PopupMenuItem(
                            value: _LogCardAction.restore,
                            child: Text('Restore'),
                          ),
                        if (onPermanentlyDelete != null)
                          const PopupMenuItem(
                            value: _LogCardAction.permanentlyDelete,
                            child: Text('Delete permanently'),
                          ),
                      ];
                    },
                  )
                else if (onEdit != null)
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.previewText,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.isLegacyEntry) ...[
              const SizedBox(height: 10),
              Text(
                'Legacy entry',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (entry.isActive && (onArchive != null || onDelete != null)) {
      return Dismissible(
        key: ValueKey('entry-${entry.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onArchive?.call();
          } else {
            onDelete?.call();
          }
          return false;
        },
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.archive_outlined, color: Colors.blue.shade500),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.only(bottom: 12),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: Colors.red.shade400,
          ),
        ),
        child: child,
      );
    }

    return child;
  }

  bool get _hasMenuActions {
    return onEdit != null || onRestore != null || onPermanentlyDelete != null;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    this.tint,
  });

  final IconData icon;
  final String text;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTint = tint ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveTint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveTint),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: effectiveTint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
