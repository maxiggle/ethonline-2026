import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/auth/view/login_screen.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Chapter2App extends StatelessWidget {
  const Chapter2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(authService: locator<AuthService>()),
        ),
        BlocProvider<DashboardCubit>(
          create: (_) =>
              DashboardCubit(apiService: locator<Chapter2ApiService>())
                ..loadDashboardMetrics(),
        ),
        BlocProvider<ApprovalCubit>(
          create: (_) =>
              ApprovalCubit(apiService: locator<Chapter2ApiService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Chapter 2 Guardian',
        theme: Chapter2Theme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            if (!authState.isAuthenticated) {
              return LoginScreen(
                onLoginSuccess: () {
                  context.read<DashboardCubit>().loadDashboardMetrics();
                },
              );
            }
            return const CommandCenterShell();
          },
        ),
      ),
    );
  }
}

class CommandCenterShell extends StatelessWidget {
  const CommandCenterShell({super.key});

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Chapter2Theme.background,
        appBar: _buildAppBar(context),
        body: RefreshIndicator(
          color: Chapter2Theme.primaryCyan,
          backgroundColor: Chapter2Theme.surface,
          onRefresh: () async {
            await context.read<DashboardCubit>().loadDashboardMetrics();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIdentityHeader(context),
                const SizedBox(height: 14),
                _buildAgentStatusCard(context),
                const SizedBox(height: 16),
                _buildScenarioSandbox(context),
                const SizedBox(height: 16),
                _buildRecentActivitySection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Chapter2Theme.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Chapter2Theme.primaryCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'CHAPTER 2',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Chapter2Theme.neonTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Chapter2Theme.neonTeal.withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'Base Sepolia',
              style: TextStyle(
                color: Chapter2Theme.neonTeal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh Treasury Status',
          icon: const Icon(Icons.refresh_rounded, size: 22),
          onPressed: () {
            context.read<DashboardCubit>().loadDashboardMetrics();
          },
        ),
        IconButton(
          tooltip: 'Sign Out',
          icon: const Icon(
            Icons.logout_rounded,
            size: 20,
            color: Chapter2Theme.textMuted,
          ),
          onPressed: () {
            context.read<AuthCubit>().logout();
          },
        ),
      ],
    );
  }

  Widget _buildIdentityHeader(BuildContext context) {
    final user = context.select((AuthCubit c) => c.state.user);
    final walletAddress = user?.walletAddress ?? '';
    final truncatedWallet = walletAddress.isNotEmpty
        ? (walletAddress.length > 12
              ? '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}'
              : walletAddress)
        : 'Not provisioned';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Chapter2Theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Chapter2Theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(
                  0xFF6366F1,
                ).withValues(alpha: 0.25),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.email ?? 'Authenticated Operator',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Chapter2Theme.neonTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Privy Biometric Signer Active',
                          style: TextStyle(
                            color: Chapter2Theme.neonTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Chapter2Theme.border),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: walletAddress));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied Privy Wallet: $walletAddress'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF238636),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Chapter2Theme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Chapter2Theme.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Chapter2Theme.primaryCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Privy Embedded EVM:',
                    style: TextStyle(
                      color: Chapter2Theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      truncatedWallet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Chapter2Theme.primaryCyan,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentStatusCard(BuildContext context) {
    final metrics = context.select((DashboardCubit c) => c.state.metrics);
    final spent = metrics?.todaySpentUsdc ?? 0.0;
    final cap = metrics?.dailyAutonomousCapUsdc ?? 0.0;
    final burnPercent = cap > 0 ? (spent / cap).clamp(0.0, 1.0) : 0.0;
    final percentDisplay = (burnPercent * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Chapter2Theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Chapter2Theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    color: Chapter2Theme.neonTeal,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Autonomous Treasury Agent',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Chapter2Theme.neonTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SUPERVISED',
                  style: TextStyle(
                    color: Chapter2Theme.neonTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Safe: 0x4f71...1df6  •  Guard: 0x9b60...e7d3',
            style: TextStyle(
              color: Chapter2Theme.textMuted,
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today Autonomous Spend',
                style: TextStyle(color: Chapter2Theme.textMuted, fontSize: 12),
              ),
              Text(
                metrics != null
                    ? '\${spent.toStringAsFixed(0)} / \${cap.toStringAsFixed(0)} USDC ($percentDisplay%)'
                    : 'Connecting...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: metrics != null ? burnPercent : 0.0,
              minHeight: 6,
              backgroundColor: Chapter2Theme.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(Chapter2Theme.neonTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSandbox(BuildContext context) {
    final isBusy = context.select(
      (DashboardCubit c) => c.state.isSubmittingScenario,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Chapter2Theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Chapter2Theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'END-TO-END SCENARIOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Chapter2Theme.primaryCyan,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Test real-time tri-verdict evaluations on Base Sepolia:',
            style: TextStyle(color: Chapter2Theme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Scenario 1: ALLOW
          _buildScenarioCard(
            context: context,
            title: '1. Autonomous Allow (\$40 USDC)',
            subtitle: 'RPC subscription within \$500 limit. Auto-executes.',
            badgeText: 'ALLOW',
            badgeColor: Chapter2Theme.neonTeal,
            icon: Icons.check_circle_outline_rounded,
            buttonText: 'Trigger Autonomous Allow',
            onTap: isBusy
                ? null
                : () => context
                      .read<DashboardCubit>()
                      .triggerAutonomousAllowScenario(),
          ),
          const SizedBox(height: 10),

          // Scenario 2: ESCALATE
          _buildScenarioCard(
            context: context,
            title: '2. Human Escalation (\$850 USDC)',
            subtitle:
                'Critical infrastructure renewal. Prompts Face ID clear-sign.',
            badgeText: 'ESCALATE',
            badgeColor: Chapter2Theme.warningAmber,
            icon: Icons.security_update_warning_rounded,
            buttonText: 'Trigger Escalation & Sign',
            onTap: isBusy
                ? null
                : () =>
                      context.read<DashboardCubit>().triggerEscalateScenario(),
          ),
          const SizedBox(height: 10),

          // Scenario 3: BLOCK
          _buildScenarioCard(
            context: context,
            title: '3. Threat Block (\$5,000 USDC)',
            subtitle: 'Untrusted destination address. Blocked by AI Guardian.',
            badgeText: 'BLOCK',
            badgeColor: Chapter2Theme.alertRed,
            icon: Icons.gpp_bad_outlined,
            buttonText: 'Simulate Adversarial Threat',
            onTap: isBusy
                ? null
                : () => context
                      .read<DashboardCubit>()
                      .triggerBlockThreatScenario(),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required String buttonText,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Chapter2Theme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Chapter2Theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Chapter2Theme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: badgeColor.withValues(alpha: 0.15),
                      foregroundColor: badgeColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: badgeColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    final actions = context.select((DashboardCubit c) => c.state.recentActions);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Chapter2Theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Chapter2Theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE ACTIVITY FEED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                ),
              ),
              Text(
                '${actions.length} records',
                style: const TextStyle(
                  color: Chapter2Theme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (actions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No transactions recorded yet. Tap any test scenario above!',
                  style: TextStyle(
                    color: Chapter2Theme.textMuted,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length > 5 ? 5 : actions.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 14, color: Chapter2Theme.border),
              itemBuilder: (context, index) {
                final action = actions[index];
                return _buildActionListItem(context, action);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionListItem(BuildContext context, TreasuryAction action) {
    Color statusColor;
    String statusLabel;

    switch (action.status) {
      case TreasuryActionStatus.executed:
      case TreasuryActionStatus.approved:
        statusColor = Chapter2Theme.neonTeal;
        statusLabel = 'EXECUTED';
        break;
      case TreasuryActionStatus.pending:
        statusColor = Chapter2Theme.warningAmber;
        statusLabel = 'ESCALATED';
        break;
      case TreasuryActionStatus.rejected:
        statusColor = Chapter2Theme.alertRed;
        statusLabel = 'BLOCKED';
        break;
      case TreasuryActionStatus.expired:
        statusColor = Chapter2Theme.textMuted;
        statusLabel = 'EXPIRED';
        break;
    }

    return InkWell(
      onTap: action.status == TreasuryActionStatus.pending
          ? () => _showBiometricApprovalSheet(context, action)
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.purpose.isNotEmpty
                        ? action.purpose
                        : 'Autonomous Transfer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To: ${action.recipientAddress.length > 10 ? '${action.recipientAddress.substring(0, 6)}...${action.recipientAddress.substring(action.recipientAddress.length - 4)}' : action.recipientAddress}',
                    style: const TextStyle(
                      color: Chapter2Theme.textMuted,
                      fontFamily: 'Courier',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${action.amountDisplayUsdc.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
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
    final user = context.read<AuthCubit>().state.user;
    final userWallet = user?.walletAddress ?? '';

    final payload = Eip712ApprovalPayload(
      actionId: action.actionId,
      agentAddress: action.agentAddress,
      recipientAddress: action.recipientAddress,
      tokenAddress: action.tokenAddress,
      amountUnits: action.amountUnits,
      nonce: action.nonce ?? 1,
      deadline: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      mandateHash: '0xCHAPTER2_MANDATE_HASH',
      riskScore: action.riskScore,
    );

    context.read<ApprovalCubit>().initializeApproval(payload);

    showModalBottomSheet(
      context: context,
      backgroundColor: Chapter2Theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return BlocConsumer<ApprovalCubit, ApprovalState>(
          listener: (ctx, state) {
            if (state.status == ApprovalStepStatus.approvedSuccess) {
              context.read<DashboardCubit>().clearPendingEscalation();
              context.read<DashboardCubit>().loadDashboardMetrics();
            }
          },
          builder: (ctx, state) {
            final isDone = state.status == ApprovalStepStatus.approvedSuccess;
            final isSigning =
                state.status == ApprovalStepStatus.signing ||
                state.status == ApprovalStepStatus.biometricsPrompt;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Chapter2Theme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDone
                                ? Chapter2Theme.neonTeal.withValues(alpha: 0.15)
                                : Chapter2Theme.warningAmber.withValues(
                                    alpha: 0.15,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : Icons.fingerprint_rounded,
                            color: isDone
                                ? Chapter2Theme.neonTeal
                                : Chapter2Theme.warningAmber,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDone
                                    ? 'Escalation Approved!'
                                    : 'Biometric Clear-Signing',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDone
                                    ? 'Safe executed transaction on Base Sepolia'
                                    : 'Privy Non-Custodial Embedded Wallet',
                                style: const TextStyle(
                                  color: Chapter2Theme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Clear-Sign Details Table
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Chapter2Theme.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Chapter2Theme.border),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Action ID', action.actionId),
                          _buildDetailRow(
                            'Amount',
                            '\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                            highlight: true,
                          ),
                          _buildDetailRow(
                            'Recipient',
                            action.recipientAddress,
                            isMono: true,
                          ),
                          _buildDetailRow(
                            'Risk Score',
                            '${action.riskScore} / 100 (HIGH RISK)',
                            alert: true,
                          ),
                          _buildDetailRow(
                            'Signer',
                            userWallet.isNotEmpty
                                ? userWallet
                                : 'Unassigned Signer',
                            isMono: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (isDone) ...[
                      if (state.txHash != null && state.txHash!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Chapter2Theme.neonTeal.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Chapter2Theme.neonTeal.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                color: Chapter2Theme.neonTeal,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tx: ${state.txHash}',
                                  style: const TextStyle(
                                    color: Chapter2Theme.neonTeal,
                                    fontFamily: 'Courier',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          context.read<ApprovalCubit>().reset();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Chapter2Theme.neonTeal,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: isSigning
                            ? null
                            : () {
                                if (userWallet.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No authenticated wallet address found for biometric signing.',
                                      ),
                                      backgroundColor: Chapter2Theme.alertRed,
                                    ),
                                  );
                                  return;
                                }
                                final sig = state.payload?.signatureHex ?? '';
                                context
                                    .read<ApprovalCubit>()
                                    .approveWithPrivyBiometrics(
                                      walletAddress: userWallet,
                                      signature: sig,
                                    );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSigning
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.fingerprint_rounded, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Approve with Face ID (Privy Wallet)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool highlight = false,
    bool isMono = false,
    bool alert = false,
  }) {
    Color valueColor = Colors.white;
    if (highlight) valueColor = Chapter2Theme.neonTeal;
    if (alert) valueColor = Chapter2Theme.warningAmber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Chapter2Theme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor,
                fontFamily: isMono ? 'Courier' : null,
                fontWeight: highlight || alert
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
