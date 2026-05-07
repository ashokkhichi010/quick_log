import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/soft_ui.dart';
import '../../../shared/widgets/bottom_nav_item.dart';
import '../../logs/presentation/screens/active_logs_screen.dart';
import '../../recording/presentation/widgets/recording_bottom_sheet.dart';

enum HomeNavItem {
  home,
  archived,
  record,
  trash,
  settings,
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Log')),
      body: const ActiveLogsScreen(),
      bottomNavigationBar: const _HomeBottomNavigationBar(),
    );
  }
}

class _HomeBottomNavigationBar extends StatelessWidget {
  const _HomeBottomNavigationBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              BottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: true,
                onTap: () {},
              ),
              BottomNavItem(
                icon: Icons.mic_rounded,
                label: 'Record',
                selected: false,
                isPrimaryAction: true,
                onTap: () => showRecordingBottomSheet(context),
              ),
              BottomNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: false,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.settings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
