import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCubit>().loadDashboardMetrics();
    });
  }

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
            context.router.replace(LoginRoute());
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
        : 'Connecting to wallet...';

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
                      user?.email ?? (user?.name ?? 'Authenticated Operator'),
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
            onTap: walletAddress.isNotEmpty
                ? () {
                    Clipboard.setData(ClipboardData(text: walletAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied Privy Wallet: $walletAddress'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF238636),
                      ),
                    );
                  }
                : null,
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (walletAddress.isNotEmpty)
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Chapter2Theme.neonTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
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
            'Safe: 0x4f71...1df6   •   Guard: 0x9b60...e7d3',
            style: TextStyle(
              color: Chapter2Theme.textMuted,
              fontFamily: 'Courier',
              fontSize: 12,
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
              Flexible(
                child: Text(
                  metrics != null
                      ? '\$${spent.toStringAsFixed(0)} / \$${cap.toStringAsFixed(0)} USDC ($percentDisplay%)'
                      : 'Loading limit...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: metrics != null ? burnPercent : 0.0,
              minHeight: 6,
              backgroundColor: Chapter2Theme.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Chapter2Theme.neonTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSandbox(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'END-TO-END SCENARIOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Test real-time tri-verdict evaluations on Base Sepolia:',
          style: TextStyle(color: Chapter2Theme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildScenarioCard(
          context,
          title: '1. Autonomous Allow (\$40 USDC)',
          subtitle: 'RPC subscription within \$500 limit. Auto-executes.',
          badgeText: 'ALLOW',
          badgeColor: Chapter2Theme.neonTeal,
          icon: Icons.check_circle_outline_rounded,
          buttonText: 'Trigger Autonomous Allow',
          onTap: () {
            context.read<DashboardCubit>().triggerAutonomousAllowScenario();
          },
        ),
        const SizedBox(height: 10),
        _buildScenarioCard(
          context,
          title: '2. Human Escalation (\$850 USDC)',
          subtitle:
              'Critical infrastructure renewal. Prompts Face ID clear-sign.',
          badgeText: 'ESCALATE',
          badgeColor: const Color(0xFFF59E0B),
          icon: Icons.fingerprint_rounded,
          buttonText: 'Trigger Escalation & Sign',
          buttonColor: const Color(0xFFD97706),
          onTap: () {
            context.read<DashboardCubit>().triggerEscalateScenario();
          },
        ),
        const SizedBox(height: 10),
        _buildScenarioCard(
          context,
          title: '3. Threat Block (\$5,000 USDC)',
          subtitle: 'Untrusted destination address. Blocked by AI Guardian.',
          badgeText: 'BLOCK',
          badgeColor: Chapter2Theme.alertRed,
          icon: Icons.shield_outlined,
          buttonText: 'Simulate Adversarial Threat',
          buttonColor: const Color(0xFF991B1B),
          onTap: () {
            context.read<DashboardCubit>().triggerBlockThreatScenario();
          },
        ),
      ],
    );
  }

  Widget _buildScenarioCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required String buttonText,
    Color? buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Chapter2Theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Chapter2Theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: (buttonColor ?? const Color(0xFF238636))
                    .withValues(alpha: 0.25),
                foregroundColor: buttonColor ?? Chapter2Theme.neonTeal,
                side: BorderSide(
                  color: (buttonColor ?? const Color(0xFF238636)).withValues(
                    alpha: 0.5,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    final actions = context.select((DashboardCubit c) => c.state.recentActions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE ACTIVITY FEED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${actions.length} events recorded',
              style: const TextStyle(
                color: Chapter2Theme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (actions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Chapter2Theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Chapter2Theme.border),
            ),
            alignment: Alignment.center,
            child: const Text(
              'No treasury activity recorded yet. Run a scenario above!',
              style: TextStyle(color: Chapter2Theme.textMuted, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final action = actions[index];
              final isAllow =
                  action.status == TreasuryActionStatus.executed ||
                  action.status == TreasuryActionStatus.approved;
              final isEscalate = action.status == TreasuryActionStatus.pending;
              final color = isAllow
                  ? Chapter2Theme.neonTeal
                  : (isEscalate
                        ? const Color(0xFFF59E0B)
                        : Chapter2Theme.alertRed);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Chapter2Theme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Chapter2Theme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.purpose,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target: ${action.recipientAddress}',
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
                          '\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.status.name.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
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
      backgroundColor: Chapter2Theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  ),
                  backgroundColor: const Color(0xFF238636),
                ),
              );
            } else if (state.status == ApprovalStepStatus.failure) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Approval failed: ${state.errorMessage ?? "Unknown error"}',
                  ),
                  backgroundColor: Chapter2Theme.alertRed,
                ),
              );
            }
          },
          builder: (context, state) {
            final isSigning = state.status == ApprovalStepStatus.signing;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Biometric Clear-Signing Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Chapter2Theme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Chapter2Theme.border),
                    ),
                    child: Column(
                      children: [
                        _buildSheetRow(
                          'Amount',
                          '\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        _buildSheetRow('Purpose', action.purpose),
                        const SizedBox(height: 8),
                        _buildSheetRow(
                          'Destination',
                          action.recipientAddress,
                          isCourier: true,
                        ),
                        const SizedBox(height: 8),
                        _buildSheetRow(
                          'Safe Nonce',
                          (action.nonce ?? 0).toString(),
                        ),
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
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSigning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : const Text(
                            'Authorize with Face ID / Keyring',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
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
          style: const TextStyle(color: Chapter2Theme.textMuted, fontSize: 12),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              fontFamily: isCourier ? 'Courier' : null,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
