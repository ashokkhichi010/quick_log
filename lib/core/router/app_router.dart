import 'package:flutter/material.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/logs/archived/presentation/archived_logs_screen.dart';
import '../../features/logs/trash/presentation/deleted_logs_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const settings = '/settings';
  static const archivedLogs = '/archived-logs';
  static const deletedLogs = '/deleted-logs';
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.settings:
        return _buildRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.archivedLogs:
        return _buildRoute(
          settings: settings,
          builder: (_) => const ArchivedLogsScreen(),
        );
      case AppRoutes.deletedLogs:
        return _buildRoute(
          settings: settings,
          builder: (_) => const DeletedLogsScreen(),
        );
      case AppRoutes.home:
      default:
        return _buildRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
    }
  }

  static MaterialPageRoute<void> _buildRoute({
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) {
    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }
}
