import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/export_format.dart';
import '../../features/logs/domain/category.dart';
import '../../features/logs/domain/log_entry.dart';
import '../../features/logs/domain/log_entry_flavor.dart';

class ExportResult {
  const ExportResult({required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;
}

abstract class ExportService {
  Future<ExportResult> exportEntries({
    required ExportFormat format,
    required List<LogEntry> entries,
    required List<Category> categories,
  });
}

class ExportContentBuilder {
  const ExportContentBuilder();

  String build({
    required ExportFormat format,
    required List<LogEntry> entries,
    required List<Category> categories,
  }) {
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return switch (format) {
      ExportFormat.csv => _buildCsv(entries, categoryNames),
      ExportFormat.json => _buildJson(entries, categoryNames),
    };
  }

  String _buildCsv(List<LogEntry> entries, Map<String, String> categoryNames) {
    final buffer = StringBuffer()
      ..writeln('Date,Time,Transcript,Important,Type');

    for (final entry in entries) {
      final values = [
        DateFormat('yyyy-MM-dd').format(entry.createdAt),
        DateFormat('hh:mm a').format(entry.createdAt),
        entry.transcriptText,
        entry.isImportant.toString(),
        entry.flavor.label,
      ];
      buffer.writeln(values.map((value) => _escapeCsv(value)).join(','));
    }

    return buffer.toString();
  }

  String _buildJson(List<LogEntry> entries, Map<String, String> categoryNames) {
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert([
      for (final entry in entries)
        <String, Object?>{
          'id': entry.id,
          'timestamp': entry.timestamp.toIso8601String(),
          'transcript': entry.transcriptText,
          'important': entry.isImportant,
          'type': entry.flavor.name,
          'category': categoryNames[entry.categoryId] ?? entry.categoryId,
          'createdAt': entry.createdAt.toIso8601String(),
          'updatedAt': entry.updatedAt.toIso8601String(),
        },
    ]);
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class LocalExportService implements ExportService {
  const LocalExportService({
    this.contentBuilder = const ExportContentBuilder(),
  });

  final ExportContentBuilder contentBuilder;

  @override
  Future<ExportResult> exportEntries({
    required ExportFormat format,
    required List<LogEntry> entries,
    required List<Category> categories,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'quick_log_$timestamp${format.extension}';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    final content = contentBuilder.build(
      format: format,
      entries: entries,
      categories: categories,
    );

    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: 'Quick Log export',
        text: 'Quick Log ${format.label} export',
        subject: 'Quick Log ${format.label} export',
      ),
    );

    return ExportResult(filePath: file.path, fileName: fileName);
  }
}
