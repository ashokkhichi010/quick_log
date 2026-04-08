import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_log/src/app/app.dart';
import 'package:quick_log/src/app/app_providers.dart';
import 'package:quick_log/src/features/logs/domain/category.dart';
import 'package:quick_log/src/features/settings/domain/app_settings.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('splash navigates to logs and quick add saves an entry', (
    tester,
  ) async {
    final entriesRepository = FakeEntriesRepository();
    final categoriesRepository = FakeCategoriesRepository(Category.seededCategories);
    final settingsRepository = FakeSettingsRepository(const AppSettings.defaults());
    final notificationsService = FakeNotificationsService();
    final exportService = FakeExportService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesRepositoryProvider.overrideWithValue(entriesRepository),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepository),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationsServiceProvider.overrideWithValue(notificationsService),
          exportServiceProvider.overrideWithValue(exportService),
        ],
        child: const QuickLogApp(),
      ),
    );

    expect(find.text('Quick Log'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Quick Add Entry'), findsOneWidget);

    await tester.tap(find.text('Quick Add Entry'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Implemented daily logging flow',
    );
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(find.text('Implemented daily logging flow'), findsOneWidget);
  });
}
