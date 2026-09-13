import 'package:auto_route/auto_route.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/activity/view/activity_timeline_screen.dart';
import 'package:chapter2/features/dashboard/view/dashboard_screen.dart';
import 'package:chapter2/features/services/view/services_screen.dart';
import 'package:chapter2/features/shell/shell_tab_controller.dart';
import 'package:chapter2/features/x402_approvals/view/x402_approvals_screen.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';

/// The post-auth, post-onboarding shell: Home, Services, Approvals and
/// Activity behind a Material 3 [NavigationBar]. Settings opens from Home's
/// header icon.
@RoutePage()
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _selectTab(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    locator<ShellTabController>().addListener(_onExternalTabSelection);
  }

  @override
  void dispose() {
    locator<ShellTabController>().removeListener(_onExternalTabSelection);
    super.dispose();
  }

  /// Reacts to a tab selected from outside the shell, e.g. the purchase
  /// detail screen's "Open Approvals" link.
  void _onExternalTabSelection() {
    final index = locator<ShellTabController>().value;
    if (index != _currentIndex) _selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            onOpenApprovals: () => _selectTab(2),
            onOpenActivity: () => _selectTab(3),
          ),
          const ServicesScreen(),
          const X402ApprovalsScreen(),
          const ActivityTimelineScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.storefront_rounded), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.verified_user_rounded), label: 'Approvals'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
        ],
      ),
    );
  }
}
