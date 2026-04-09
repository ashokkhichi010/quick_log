import 'package:flutter/material.dart';

import '../features/logs/presentation/logs_screen.dart';
import '../features/session/presentation/check_in_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const checkIn = '/check-in';
  static const logs = '/logs';
  static const settings = '/settings';
}

Route<dynamic> generateAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return MaterialPageRoute<void>(
        builder: (_) => const SplashScreen(),
        settings: settings,
      );
    case AppRoutes.settings:
      return MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
        settings: settings,
      );
    case AppRoutes.checkIn:
      return MaterialPageRoute<void>(
        builder: (_) => const CheckInScreen(),
        settings: settings,
      );
    case AppRoutes.logs:
    default:
      return MaterialPageRoute<void>(
        builder: (_) => const LogsScreen(),
        settings: settings,
      );
  }
}
