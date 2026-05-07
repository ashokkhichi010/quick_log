import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_log/core/models/export_format.dart';
import 'package:quick_log/core/services/export_service.dart';
import 'package:quick_log/features/logs/domain/category.dart';
import 'package:quick_log/features/logs/domain/log_entry.dart';

void main() {
  final builder = const ExportContentBuilder();
  final category = Category(id: 'flutter', name: 'Flutter', isDefault: true);
  final entry = LogEntry.voice(
    id: 'entry-1',
    transcript: 'Built the voice capture flow and tested export.',
    createdAt: DateTime(2026, 4, 8, 10, 30),
    isImportant: true,
  );

  test('builds CSV with transcript-first headers', () {
    final csv = builder.build(
      format: ExportFormat.csv,
      entries: [entry],
      categories: [category],
    );

    expect(csv, contains('Date,Time,Transcript,Important,Type'));
    expect(csv, contains('"Built the voice capture flow and tested export."'));
    expect(csv, contains('"Voice"'));
  });

  test('builds JSON with transcript and type', () {
    final jsonString = builder.build(
      format: ExportFormat.json,
      entries: [entry],
      categories: [category],
    );

    final decoded = jsonDecode(jsonString) as List<dynamic>;
    expect(decoded, hasLength(1));
    expect(decoded.first['transcript'], contains('voice capture flow'));
    expect(decoded.first['important'], true);
    expect(decoded.first['type'], 'voice');
  });
}
