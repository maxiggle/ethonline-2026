import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/activity/view/activity_timeline_screen.dart';
import 'package:chapter2/features/agents/view/agent_detail_screen.dart';
import 'package:chapter2/features/dashboard/view/dashboard_screen.dart';
import 'package:chapter2/features/settings/view/settings_screen.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';

@RoutePage()
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardScreen(onNavigateToTab: _onTabSelected),
      const ActivityTimelineScreen(),
      const AgentDetailScreen(),
      SettingsScreen(
        onSignOut: () {
          context.router.replace(LoginRoute());
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.screenBackgroundElevated,
          border: Border(
            top: BorderSide(color: AppColors.actionPillBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.space_dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.receipt_long_rounded, 'Activity'),
                _buildNavItem(2, Icons.smart_toy_rounded, 'Agents'),
                _buildNavItem(3, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.white : AppColors.textLightMuted;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.actionPillBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.actionPillBorder),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.brandPrimary : color,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.xs(
                  context,
                  color: Colors.white,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
