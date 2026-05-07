import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/services/notifications_service.dart';
import '../features/logs/presentation/reminder_alert_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/settings/domain/app_settings.dart';
import 'app_providers.dart';
import 'theme/app_theme.dart';

class QuickLogApp extends ConsumerStatefulWidget {
  const QuickLogApp({super.key});

  @override
  ConsumerState<QuickLogApp> createState() => _QuickLogAppState();
}

class _QuickLogAppState extends ConsumerState<QuickLogApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<ReminderAlertEvent>? _reminderSubscription;
  bool _isPresentingReminderAlert = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final notificationsService = ref.read(notificationsServiceProvider);
      _reminderSubscription = notificationsService.reminderAlerts.listen(
        _presentReminderAlert,
      );

      final initialReminderAlert = notificationsService
          .consumeInitialReminderAlert();
      if (initialReminderAlert != null) {
        _presentReminderAlert(initialReminderAlert);
      }
    });
  }

  @override
  void dispose() {
    _reminderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(appSettingsControllerProvider);

    return MaterialApp(
      title: 'Quick Log',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsState.settings.themeMode.asThemeMode,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: (initialRoute) {
        return [
          MaterialPageRoute<void>(
            builder: (_) => const SplashScreen(),
            settings: const RouteSettings(name: 'startup-splash'),
          ),
        ];
      },
    );
  }

  Future<void> _presentReminderAlert(ReminderAlertEvent event) async {
    if (_isPresentingReminderAlert) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      return;
    }

    _isPresentingReminderAlert = true;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ReminderAlertScreen(event: event),
        fullscreenDialog: true,
        settings: const RouteSettings(name: 'reminder-alert'),
      ),
    );
    _isPresentingReminderAlert = false;
  }
}
