import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_log/app/app.dart';
import 'package:quick_log/app/app_providers.dart';
import 'package:quick_log/features/logs/domain/log_entry.dart';
import 'package:quick_log/features/logs/domain/category.dart';
import 'package:quick_log/features/settings/domain/app_settings.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('splash navigates home and recording sheet saves a transcript', (
    tester,
  ) async {
    final entriesRepository = FakeEntriesRepository();
    final categoriesRepository = FakeCategoriesRepository(
      Category.seededCategories,
    );
    final settingsRepository = FakeSettingsRepository(
      const AppSettings.defaults(),
    );
    final notificationsService = FakeNotificationsService();
    final exportService = FakeExportService();
    final speechService = FakeSpeechService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesRepositoryProvider.overrideWithValue(entriesRepository),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepository),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationsServiceProvider.overrideWithValue(notificationsService),
          exportServiceProvider.overrideWithValue(exportService),
          speechServiceProvider.overrideWithValue(speechService),
        ],
        child: const QuickLogApp(),
      ),
    );

    expect(find.text('Quick Log'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('No logs yet'), findsOneWidget);

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Quick record'), findsOneWidget);
    expect(find.text('Recording...'), findsOneWidget);

    speechService.emitResult('Finished API review and fixed login bug');
    await tester.pump();

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Review transcript'), findsOneWidget);
    expect(find.text('Save'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(entriesRepository.entriesSnapshot, hasLength(1));
    expect(
      entriesRepository.entriesSnapshot.single.transcriptText,
      contains('Finished API review'),
    );
  });

  testWidgets('bottom navigation opens archived, trash, and settings routes', (
    tester,
  ) async {
    final entriesRepository = FakeEntriesRepository([
      LogEntry.voice(
        id: 'active-1',
        transcript: 'Active task update',
      ),
      LogEntry.voice(
        id: 'archived-1',
        transcript: 'Archived note',
      ).copyWith(archivedAt: DateTime.now()),
      LogEntry.voice(
        id: 'trash-1',
        transcript: 'Deleted note',
      ).copyWith(deletedAt: DateTime.now()),
    ]);
    final categoriesRepository = FakeCategoriesRepository(
      Category.seededCategories,
    );
    final settingsRepository = FakeSettingsRepository(
      const AppSettings.defaults(),
    );
    final notificationsService = FakeNotificationsService();
    final exportService = FakeExportService();
    final speechService = FakeSpeechService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesRepositoryProvider.overrideWithValue(entriesRepository),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepository),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationsServiceProvider.overrideWithValue(notificationsService),
          exportServiceProvider.overrideWithValue(exportService),
          speechServiceProvider.overrideWithValue(speechService),
        ],
        child: const QuickLogApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Active task update'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Archived Logs'), findsOneWidget);
    expect(find.text('Archived note'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted Logs'), findsOneWidget);
    expect(find.text('Deleted note'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
  });
}
