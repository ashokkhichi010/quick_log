import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import 'app_providers.dart';
import 'app_routes.dart';
import 'theme/app_theme.dart';

class QuickLogApp extends ConsumerWidget {
  const QuickLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(appSettingsControllerProvider);

    return MaterialApp(
      title: 'Quick Log',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsState.settings.themeMode.asThemeMode,
      onGenerateRoute: generateAppRoute,
      initialRoute: AppRoutes.splash,
    );
  }
}
