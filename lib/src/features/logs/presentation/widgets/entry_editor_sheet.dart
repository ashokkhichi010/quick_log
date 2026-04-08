import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatters.dart';
import '../../../../core/widgets/soft_ui.dart';
import '../../domain/category.dart';
import '../../domain/entry_result.dart';
import '../../domain/log_entry.dart';

Future<LogEntryDraft?> showEntryEditorSheet({
  required BuildContext context,
  required List<Category> categories,
  required String initialCategoryId,
  required EntryResult initialResult,
  LogEntry? existingEntry,
}) {
  return showModalBottomSheet<LogEntryDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EntryEditorSheet(
      categories: categories,
      initialCategoryId: initialCategoryId,
      initialResult: initialResult,
      existingEntry: existingEntry,
    ),
  );
}

class EntryEditorSheet extends StatefulWidget {
  const EntryEditorSheet({
    super.key,
    required this.categories,
    required this.initialCategoryId,
    required this.initialResult,
    this.existingEntry,
  });

  final List<Category> categories;
  final String initialCategoryId;
  final EntryResult initialResult;
  final LogEntry? existingEntry;

  @override
  State<EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends State<EntryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _taskController;
  late final TextEditingController _problemController;
  late final TextEditingController _solutionController;
  late final TextEditingController _notesController;

  late DateTime _timestamp;
  late String _selectedCategoryId;
  late EntryResult _selectedResult;
  late bool _showDetails;

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _timestamp = entry?.timestamp ?? DateTime.now();
    _selectedCategoryId = _resolveInitialCategory(entry);
    _selectedResult = entry?.result ?? widget.initialResult;
    _showDetails =
        entry?.problem != null ||
        entry?.solutionTried != null ||
        entry?.notes != null;
    _taskController = TextEditingController(text: entry?.task ?? '');
    _problemController = TextEditingController(text: entry?.problem ?? '');
    _solutionController = TextEditingController(
      text: entry?.solutionTried ?? '',
    );
    _notesController = TextEditingController(text: entry?.notes ?? '');
  }

  String _resolveInitialCategory(LogEntry? entry) {
    final desiredCategoryId = entry?.categoryId ?? widget.initialCategoryId;
    final exists = widget.categories.any(
      (item) => item.id == desiredCategoryId,
    );
    return exists ? desiredCategoryId : widget.categories.first.id;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _problemController.dispose();
    _solutionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, viewInsets.bottom + 16),
      child: SoftSurface(
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existingEntry == null
                            ? 'Quick add entry'
                            : 'Edit entry',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Designed for logging in a few seconds.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _taskController,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: widget.existingEntry == null,
                  decoration: const InputDecoration(
                    labelText: 'Task / Activity',
                    hintText: 'What are you doing?',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Task is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text(formatEntryTime(_timestamp)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: [
                          for (final category in widget.categories)
                            DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Result', style: theme.textTheme.labelLarge),
                const SizedBox(height: 10),
                SegmentedButton<EntryResult>(
                  segments: [
                    for (final result in EntryResult.values)
                      ButtonSegment<EntryResult>(
                        value: result,
                        label: Text(result.label),
                      ),
                  ],
                  selected: {_selectedResult},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedResult = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  icon: Icon(
                    _showDetails
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(
                    _showDetails
                        ? 'Hide optional details'
                        : 'Add optional details',
                  ),
                ),
                if (_showDetails) ...[
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _problemController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Problem Faced',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _solutionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Solution Tried',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      widget.existingEntry == null
                          ? 'Save entry'
                          : 'Update entry',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _timestamp = DateTime(
        _timestamp.year,
        _timestamp.month,
        _timestamp.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      LogEntryDraft(
        timestamp: _timestamp,
        task: _taskController.text,
        categoryId: _selectedCategoryId,
        problem: _problemController.text,
        solutionTried: _solutionController.text,
        result: _selectedResult,
        notes: _notesController.text,
      ),
    );
  }
}
