import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/utils/usdc_amount_formatter.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Home tab: an agent summary, pending Ledger escalations, and the
/// latest activity. Embedded inside [MainShellScreen] — never routed
/// directly, since Settings opens from its header icon rather than a tab.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpenApprovals, this.onOpenActivity});

  /// Switches the parent shell to the Approvals tab.
  final VoidCallback? onOpenApprovals;

  /// Switches the parent shell to the Activity tab.
  final VoidCallback? onOpenActivity;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasCheckedPendingApprovals = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCubit>().loadDashboardMetrics();
      _refreshPendingApprovals();
    });
  }

  void _refreshPendingApprovals() {
    context.read<X402ApprovalsCubit>().refreshPendingApprovals().whenComplete(() {
      if (mounted) setState(() => _hasCheckedPendingApprovals = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await context.read<DashboardCubit>().loadDashboardMetrics();
          if (context.mounted) {
            await context.read<AuthCubit>().refreshAgents();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildAgentCard(context),
              const SizedBox(height: 14),
              _buildLedgerApprovalsCard(context),
              const SizedBox(height: 14),
              _buildRecentActivityCard(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final email = context.select((AuthCubit c) => c.state.user?.email);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chapter 2', style: AppTextStyles.xxl(context, fontWeight: AppTextStyles.extraBold)),
              const SizedBox(height: 2),
              Text(
                email ?? 'Autonomous treasury supervision',
                style: AppTextStyles.sm(context, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.router.push(const SettingsRoute()),
          icon: const Icon(Icons.settings_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
      ],
    );
  }

  Widget _buildAgentCard(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final agents = authState.agents;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(context, 'Your Agent', Icons.smart_toy_rounded),
          const SizedBox(height: 14),
          if (authState.status == AuthStatus.loading && agents.isEmpty)
            _buildLoadingRow(context, 'Loading your agents...')
          else if (authState.status == AuthStatus.error)
            _buildErrorRow(
              context,
              authState.errorMessage ?? 'Could not load your agents.',
              onRetry: () => context.read<AuthCubit>().refreshAgents(),
            )
          else if (agents.isEmpty)
            _buildBindAgentCta(context)
          else
            _buildAgentSummary(context, agents.first),
        ],
      ),
    );
  }

  Widget _buildBindAgentCta(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No autonomous agent is bound to your account yet.',
          style: AppTextStyles.sm(context, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => context.router.push(OnboardingRoute(initialStep: 1)),
          icon: const Icon(Icons.add_link_rounded, size: 18),
          label: const Text('Bind your agent'),
        ),
      ],
    );
  }

  Widget _buildAgentSummary(BuildContext context, AgentModel agent) {
    final address = agent.agentAddress;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(agent.name, style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
              const SizedBox(height: 2),
              InkWell(
                onTap: () => _copyToClipboard(context, 'Agent address', address),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_shortenAddress(address), style: AppTextStyles.mono(context, fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.allowBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.allowBorder),
          ),
          child: Text(
            agent.status,
            style: AppTextStyles.xs(context, color: AppColors.allowText, fontWeight: AppTextStyles.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerApprovalsCard(BuildContext context) {
    final state = context.watch<X402ApprovalsCubit>().state;
    final pending = state.pendingApprovals;

    return InkWell(
      onTap: widget.onOpenApprovals,
      borderRadius: BorderRadius.circular(20),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(context, 'Ledger Approvals', Icons.usb_rounded),
            const SizedBox(height: 14),
            if (!_hasCheckedPendingApprovals)
              _buildLoadingRow(context, 'Checking for pending escalations...')
            else if (state.errorMessage != null && pending.isEmpty)
              _buildErrorRow(
                context,
                state.errorMessage!,
                onRetry: _refreshPendingApprovals,
              )
            else if (pending.isEmpty)
              Text(
                'No escalated payments are waiting for a signature.',
                style: AppTextStyles.sm(context, color: AppColors.textSecondary),
              )
            else
              _buildPendingApprovalSummary(context, pending),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalSummary(BuildContext context, List<PendingX402Approval> pending) {
    final first = pending.first;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.escalateBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.escalateBorder),
          ),
          child: Text(
            '${pending.length}',
            style: AppTextStyles.sm(context, color: AppColors.escalateText, fontWeight: AppTextStyles.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${UsdcAmountFormatter.format(first.amountAtomicUnits)} USDC',
                style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
              ),
              Text(
                first.resourceUrl,
                style: AppTextStyles.xs(context, color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      ],
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    final state = context.watch<DashboardCubit>().state;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardTitle(context, 'Recent Activity', Icons.receipt_long_rounded),
              InkWell(
                onTap: widget.onOpenActivity,
                child: Text('See all', style: AppTextStyles.sm(context, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (state.status == DashboardStatus.loading && state.recentActions.isEmpty)
            _buildLoadingRow(context, 'Loading recent activity...')
          else if (state.status == DashboardStatus.failure)
            _buildErrorRow(
              context,
              state.errorMessage ?? 'Could not load recent activity.',
              onRetry: () => context.read<DashboardCubit>().loadDashboardMetrics(),
            )
          else if (state.recentActions.isEmpty)
            Text(
              'No treasury actions recorded yet.',
              style: AppTextStyles.sm(context, color: AppColors.textSecondary),
            )
          else
            ...state.recentActions.take(5).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildActionRow(context, action),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, TreasuryAction action) {
    final isAllow =
        action.status == TreasuryActionStatus.executed || action.status == TreasuryActionStatus.approved;
    final isEscalate = action.status == TreasuryActionStatus.pending;

    final badgeColor = isAllow ? AppColors.allow : (isEscalate ? AppColors.escalate : AppColors.block);
    final badgeBg = isAllow
        ? AppColors.allowBackground
        : (isEscalate ? AppColors.escalateBackground : AppColors.blockBackground);
    final badgeText = isAllow ? AppColors.allowText : (isEscalate ? AppColors.escalateText : AppColors.blockText);
    final badgeLabel = isAllow ? 'ALLOW' : (isEscalate ? 'ESCALATE' : 'BLOCK');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.purpose.isNotEmpty ? action.purpose : 'Autonomous transfer',
                  style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '-\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                  style: AppTextStyles.xs(context, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badgeLabel,
              style: AppTextStyles.xs(context, color: badgeText, fontWeight: AppTextStyles.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingRow(BuildContext context, String label) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.sm(context, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildErrorRow(BuildContext context, String message, {required VoidCallback onRetry}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: AppTextStyles.sm(context, color: AppColors.blockText)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label'), behavior: SnackBarBehavior.floating),
    );
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
