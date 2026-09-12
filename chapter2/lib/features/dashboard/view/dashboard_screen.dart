import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/activity/view/activity_timeline_screen.dart';
import 'package:chapter2/features/agents/view/add_agent_sheet.dart';
import 'package:chapter2/features/agents/view/agent_detail_screen.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/dashboard/widgets/spending_sparkline_chart.dart';
import 'package:chapter2/features/guardian_alert/view/guardian_analysis_sheet.dart';
import 'package:chapter2/features/mandate/view/mandate_management_sheet.dart';
import 'package:chapter2/features/settings/view/settings_screen.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigateToTab});

  final void Function(int tabIndex)? onNavigateToTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;
  String _activityFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCubit>().loadDashboardMetrics();
    });
  }

  void _switchTab(int index) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(index);
    } else {
      setState(() => _currentTabIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHosted = widget.onNavigateToTab != null;

    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen: (prev, curr) =>
          prev.pendingEscalationAction != curr.pendingEscalationAction &&
          curr.pendingEscalationAction != null,
      listener: (context, state) {
        if (state.pendingEscalationAction != null) {
          _showBiometricApprovalSheet(context, state.pendingEscalationAction!);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: isHosted
            ? _buildHomeTab(context)
            : IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildHomeTab(context),
                  const ActivityTimelineScreen(),
                  const AgentDetailScreen(),
                  SettingsScreen(
                    onSignOut: () {
                      context.router.replace(LoginRoute());
                    },
                  ),
                ],
              ),
        bottomNavigationBar: isHosted ? null : _buildBottomNavigationBar(context),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    final color = isSelected ? Colors.white : AppColors.textLightMuted;

    return InkWell(
      onTap: () => _switchTab(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              size: 18,
              color: isSelected ? AppColors.brandPrimary : color,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
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

  Widget _buildHomeTab(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.brandPrimary,
        backgroundColor: AppColors.cardSurfacePure,
        onRefresh: () async {
          await context.read<DashboardCubit>().loadDashboardMetrics();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Hero Card (matching visual reference)
              _buildTopHeroCard(context),
              const SizedBox(height: 14),
              // Middle Floating Charcoal Action Pill Bar
              _buildMiddleActionPillBar(context),
              const SizedBox(height: 14),
              // Lower Card: Split Agent/Sparkline + Recent Activity
              _buildLowerContentCard(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Card: Light surface, user greeting, notification bell & grid, large balance, green status pill
  Widget _buildTopHeroCard(BuildContext context) {
    final user = context.select((AuthCubit c) => c.state.user);
    final metrics = context.select((DashboardCubit c) => c.state.metrics);
    final walletAddress = user?.walletAddress ?? '';
    final truncatedWallet = walletAddress.isNotEmpty
        ? (walletAddress.length > 12
            ? '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}'
            : walletAddress)
        : 'Connecting...';

    final totalBalance = metrics?.totalTreasuryBalanceUsdc;
    final spentToday = metrics?.todaySpentUsdc ?? 0.0;
    final dailyCap = metrics?.dailyAutonomousCapUsdc ?? 500.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: User Avatar/Handle + Notification & Grid Action Icons
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.15),
                child: Text(
                  user?.email?.isNotEmpty == true
                      ? user!.email!.substring(0, 2).toUpperCase()
                      : 'OP',
                  style: AppTextStyles.sm(
                    context,
                    color: AppColors.brandPrimary,
                    fontWeight: AppTextStyles.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.email ?? 'Operator',
                      style: AppTextStyles.md(
                        context,
                        color: AppColors.textPrimary,
                        fontWeight: AppTextStyles.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: walletAddress.isNotEmpty
                          ? () {
                              Clipboard.setData(ClipboardData(text: walletAddress));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied Privy EVM: $walletAddress'),
                                  backgroundColor: AppColors.allow,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.allow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            truncatedWallet,
                            style: AppTextStyles.mono(
                              context,
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (walletAddress.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 11, color: AppColors.textMuted),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Top Right Icon Buttons
              _buildTopIconButton(
                context,
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All guardian alerts verified'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildTopIconButton(
                context,
                icon: Icons.grid_view_rounded,
                tooltip: 'System Settings',
                onTap: () => _switchTab(3),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Currency / Network Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardSurfacePure,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.networkBase,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'USD · Base Sepolia',
                  style: AppTextStyles.xs(
                    context,
                    color: AppColors.textSecondary,
                    fontWeight: AppTextStyles.semiBold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Large Treasury Balance Display
          Text(
            totalBalance != null ? '\$${_formatCurrency(totalBalance)}' : '\$--.--',
            style: AppTextStyles.display(
              context,
              color: AppColors.textPrimary,
              fontWeight: AppTextStyles.extraBold,
            ),
          ),
          const SizedBox(height: 12),
          // Spend metric & status pill row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Autonomous Spend Today: \$${spentToday.toStringAsFixed(2)}',
                style: AppTextStyles.sm(context, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.allowBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.allowBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 12, color: AppColors.allowText),
                    const SizedBox(width: 4),
                    Text(
                      'Daily Cap: \$${dailyCap.toStringAsFixed(0)}',
                      style: AppTextStyles.xs(
                        context,
                        color: AppColors.allowText,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.cardSurfacePure,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  /// Middle Action Bar: Floating Dark Charcoal Pill Bar with 3 actions
  Widget _buildMiddleActionPillBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.actionPillBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.actionPillBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Action 1: Mandate ⚙
          Expanded(
            child: _buildActionPillButton(
              context,
              label: 'Mandate',
              icon: Icons.tune_rounded,
              onTap: () => MandateManagementSheet.show(context),
            ),
          ),
          // Center Action: Clear-Sign 🛡 (Primary / highlighted)
          Expanded(
            child: _buildActionPillButton(
              context,
              label: 'Clear-Sign',
              icon: Icons.shield_rounded,
              isCenterPrimary: true,
              onTap: () {
                final pending = context.read<DashboardCubit>().state.pendingEscalationAction;
                if (pending != null) {
                  _showBiometricApprovalSheet(context, pending);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No pending escalations require clear-signing right now.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
          // Action 3: + Agent 🤖
          Expanded(
            child: _buildActionPillButton(
              context,
              label: '+ Agent',
              icon: Icons.smart_toy_rounded,
              onTap: () => AddAgentSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPillButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isCenterPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: isCenterPrimary
            ? BoxDecoration(
                color: AppColors.actionPillIconBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.actionPillBorder),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isCenterPrimary ? AppColors.escalate : AppColors.actionPillForeground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.sm(
                context,
                color: AppColors.actionPillForeground,
                fontWeight: isCenterPrimary ? AppTextStyles.bold : AppTextStyles.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lower Card: Light surface with left Supervised Agents avatar bubble grid
  /// and right Today's Limit Sparkline chart, followed by Recent Activity list
  Widget _buildLowerContentCard(BuildContext context) {
    final metrics = context.select((DashboardCubit c) => c.state.metrics);
    final agents = context.select((AuthCubit c) => c.state.agents);
    final actions = context.select((DashboardCubit c) => c.state.recentActions);

    final spent = metrics?.todaySpentUsdc ?? 0.0;
    final cap = metrics?.dailyAutonomousCapUsdc ?? 2000.0;

    final filteredActions = _filterRecentActions(actions);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurfacePure,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Split section: Left Supervised Agents + Right Today's Limit Sparkline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Supervised Agents Avatar Bubbles
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: () => _switchTab(2),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supervised Agents',
                          style: AppTextStyles.xs(
                            context,
                            color: AppColors.textSecondary,
                            fontWeight: AppTextStyles.semiBold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildAgentAvatarBubble(context, '🤖', true),
                            const SizedBox(width: 8),
                            _buildAgentAvatarBubble(context, '⚡', true),
                            const SizedBox(width: 8),
                            _buildAddAgentBubble(context),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${agents.isNotEmpty ? agents.length : 1} Active · Safe Bound',
                          style: AppTextStyles.xs(
                            context,
                            color: AppColors.allowText,
                            fontWeight: AppTextStyles.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right: Today's Limit Sparkline Chart
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Limit",
                            style: AppTextStyles.xs(
                              context,
                              color: AppColors.textSecondary,
                              fontWeight: AppTextStyles.semiBold,
                            ),
                          ),
                          Text(
                            '\$${spent.toStringAsFixed(0)}/\$${cap.toStringAsFixed(0)}',
                            style: AppTextStyles.xs(
                              context,
                              color: AppColors.textPrimary,
                              fontWeight: AppTextStyles.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SpendingSparklineChart(
                        spentAmount: spent,
                        dailyCap: cap,
                        height: 52,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 18),
          // Recent Activity Header + Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: AppTextStyles.lg(
                  context,
                  color: AppColors.textPrimary,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
              InkWell(
                onTap: () => _switchTab(1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'See all',
                    style: AppTextStyles.sm(
                      context,
                      color: AppColors.brandPrimary,
                      fontWeight: AppTextStyles.semiBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick filter chips: All, Allowed, Escalated, Blocked
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSmallFilterChip('All', 'ALL'),
                const SizedBox(width: 6),
                _buildSmallFilterChip('Allowed', 'ALLOW'),
                const SizedBox(width: 6),
                _buildSmallFilterChip('Escalated', 'ESCALATE'),
                const SizedBox(width: 6),
                _buildSmallFilterChip('Blocked', 'BLOCK'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Activity list
          if (filteredActions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                'No events recorded for this filter yet.',
                style: AppTextStyles.sm(context, color: AppColors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredActions.length > 5 ? 5 : filteredActions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final action = filteredActions[index];
                return _buildRecentActionRow(context, action);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAgentAvatarBubble(BuildContext context, String emoji, bool isOnline) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.cardSurfacePure,
          child: Text(emoji, style: const TextStyle(fontSize: 14)),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.allow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddAgentBubble(BuildContext context) {
    return InkWell(
      onTap: () => AddAgentSheet.show(context),
      borderRadius: BorderRadius.circular(16),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.cardSurfacePure,
        child: const Icon(Icons.add_rounded, size: 16, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildSmallFilterChip(String label, String code) {
    final isSelected = _activityFilter == code;
    return InkWell(
      onTap: () => setState(() => _activityFilter = code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.actionPillBackground : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.actionPillBackground : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.xs(
            context,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? AppTextStyles.bold : AppTextStyles.medium,
          ),
        ),
      ),
    );
  }

  List<TreasuryAction> _filterRecentActions(List<TreasuryAction> actions) {
    if (_activityFilter == 'ALL') return actions;
    if (_activityFilter == 'ALLOW') {
      return actions.where((a) =>
          a.status == TreasuryActionStatus.executed ||
          a.status == TreasuryActionStatus.approved).toList();
    }
    if (_activityFilter == 'ESCALATE') {
      return actions.where((a) => a.status == TreasuryActionStatus.pending).toList();
    }
    if (_activityFilter == 'BLOCK') {
      return actions.where((a) => a.status == TreasuryActionStatus.rejected).toList();
    }
    return actions;
  }

  Widget _buildRecentActionRow(BuildContext context, TreasuryAction action) {
    final isAllow = action.status == TreasuryActionStatus.executed ||
        action.status == TreasuryActionStatus.approved;
    final isEscalate = action.status == TreasuryActionStatus.pending;

    final badgeColor = isAllow
        ? AppColors.allow
        : (isEscalate ? AppColors.escalate : AppColors.block);
    final badgeBg = isAllow
        ? AppColors.allowBackground
        : (isEscalate ? AppColors.escalateBackground : AppColors.blockBackground);
    final badgeText = isAllow
        ? AppColors.allowText
        : (isEscalate ? AppColors.escalateText : AppColors.blockText);
    final badgeLabel = isAllow
        ? 'ALLOW'
        : (isEscalate ? 'ESCALATE' : 'BLOCK');

    return InkWell(
      onTap: () => GuardianAnalysisSheet.show(context, action),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.cardSurfacePure,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAllow
                    ? Icons.arrow_outward_rounded
                    : (isEscalate ? Icons.fingerprint_rounded : Icons.shield_rounded),
                size: 18,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.purpose.isNotEmpty ? action.purpose : 'Autonomous Transfer',
                    style: AppTextStyles.sm(
                      context,
                      color: AppColors.textPrimary,
                      fontWeight: AppTextStyles.semiBold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${action.agentAddress.isNotEmpty ? (action.agentAddress.length > 10 ? '${action.agentAddress.substring(0, 6)}...' : action.agentAddress) : "Agent #1"} · ${_formatTime(action.timestamp)}',
                    style: AppTextStyles.xs(context, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-\$${action.amountDisplayUsdc.toStringAsFixed(2)}',
                  style: AppTextStyles.sm(
                    context,
                    color: AppColors.textPrimary,
                    fontWeight: AppTextStyles.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: AppTextStyles.xs(
                      context,
                      color: badgeText,
                      fontWeight: AppTextStyles.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBiometricApprovalSheet(
    BuildContext context,
    TreasuryAction action,
  ) {
    final authUser = context.read<AuthCubit>().state.user;
    final walletAddress = authUser?.walletAddress ?? '';

    final payload = Eip712ApprovalPayload(
      actionId: action.actionId,
      agentAddress: action.agentAddress,
      recipientAddress: action.recipientAddress,
      tokenAddress: action.tokenAddress,
      amountUnits: action.amountUnits,
      nonce: action.nonce ?? 0,
      deadline: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      mandateHash:
          '0x0000000000000000000000000000000000000000000000000000000000000000',
      riskScore: action.riskScore,
    );

    context.read<ApprovalCubit>().initializeApproval(payload);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BlocConsumer<ApprovalCubit, ApprovalState>(
          listener: (context, state) {
            if (state.status == ApprovalStepStatus.approvedSuccess) {
              Navigator.of(sheetContext).pop();
              this.context.read<DashboardCubit>().clearPendingEscalation();
              this.context.read<DashboardCubit>().loadDashboardMetrics();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Escalation approved & executed on Base Sepolia: ${state.txHash ?? ""}',
                    style: AppTextStyles.sm(this.context, color: Colors.white),
                  ),
                  backgroundColor: AppColors.allow,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state.status == ApprovalStepStatus.failure) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Approval failed: ${state.errorMessage ?? "Unknown error"}',
                    style: AppTextStyles.sm(this.context, color: Colors.white),
                  ),
                  backgroundColor: AppColors.block,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            final isSigning = state.status == ApprovalStepStatus.signing;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: AppColors.cardSurfacePure,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.escalateBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.escalateBorder),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.escalate,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biometric Clear-Signing Request',
                              style: AppTextStyles.xl(context),
                            ),
                            Text(
                              'Exceeds single-action autonomous threshold',
                              style: AppTextStyles.xs(
                                context,
                                color: AppColors.escalateText,
                                fontWeight: AppTextStyles.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _buildSheetRow(
                          context,
                          'Amount',
                          '\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                          isBold: true,
                        ),
                        const Divider(height: 14, color: AppColors.cardBorder),
                        _buildSheetRow(context, 'Purpose', action.purpose),
                        const Divider(height: 14, color: AppColors.cardBorder),
                        _buildSheetRow(
                          context,
                          'Destination',
                          action.recipientAddress,
                          isCourier: true,
                        ),
                        if (action.nonce != null) ...[
                          const Divider(height: 14, color: AppColors.cardBorder),
                          _buildSheetRow(
                            context,
                            'Safe Nonce',
                            '#${action.nonce}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSigning
                        ? null
                        : () {
                            context
                                .read<ApprovalCubit>()
                                .approveWithPrivyBiometrics(
                                  walletAddress: walletAddress,
                                  signature:
                                      '0x_privy_biometric_signature_placeholder',
                                );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPillBackground,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isSigning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Authorize with Face ID / Keyring',
                                style: AppTextStyles.md(
                                  context,
                                  color: Colors.white,
                                  fontWeight: AppTextStyles.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    bool isCourier = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.sm(context, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: isCourier
                ? AppTextStyles.mono(context, fontSize: 11)
                : AppTextStyles.sm(
                    context,
                    color: AppColors.textPrimary,
                    fontWeight: isBold ? AppTextStyles.bold : AppTextStyles.medium,
                  ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
