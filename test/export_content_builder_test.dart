import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_log/src/core/models/export_format.dart';
import 'package:quick_log/src/core/services/export_service.dart';
import 'package:quick_log/src/features/logs/domain/category.dart';
import 'package:quick_log/src/features/logs/domain/entry_result.dart';
import 'package:quick_log/src/features/logs/domain/log_entry.dart';
import 'package:quick_log/src/features/logs/domain/log_entry_type.dart';

void main() {
  final builder = const ExportContentBuilder();
  final category = Category(id: 'flutter', name: 'Flutter', isDefault: true);
  final entry = LogEntry(
    id: 'entry-1',
    timestamp: DateTime(2026, 4, 8, 10, 30),
    task: 'Built the timeline screen',
    categoryId: category.id,
    entryType: LogEntryType.manual,
    problem: 'List felt too dense',
    solutionTried: 'Grouped logs by hour',
    result: EntryResult.worked,
    notes: 'Much easier to scan',
    isImportant: true,
    createdAt: DateTime(2026, 4, 8, 10, 30),
    updatedAt: DateTime(2026, 4, 8, 10, 35),
  );

  test('builds CSV with headers and escaped values', () {
    final csv = builder.build(
      format: ExportFormat.csv,
      entries: [entry],
      categories: [category],
    );

    expect(csv, contains('id,timestamp,task,category'));
    expect(csv, contains('"Built the timeline screen"'));
    expect(csv, contains('"Flutter"'));
    expect(csv, contains('"Worked"'));
  });

  test('builds JSON with readable category names', () {
    final jsonString = builder.build(
      format: ExportFormat.json,
      entries: [entry],
      categories: [category],
    );

    final decoded = jsonDecode(jsonString) as List<dynamic>;
    expect(decoded, hasLength(1));
    expect(decoded.first['category'], 'Flutter');
    expect(decoded.first['important'], true);
    expect(decoded.first['result'], 'worked');
  });
}
