import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/mandate/view/mandate_management_sheet.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AgentDetailScreen extends StatefulWidget {
  const AgentDetailScreen({super.key});

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  bool _isPaused = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: Text(
          'Supervised Agents & Mandates',
          style: AppTextStyles.xl(context, color: Colors.white),
        ),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final agents = authState.agents;
          final activeAgent = agents.isNotEmpty ? agents.first : null;
          final safeAddr = activeAgent?.safeAddress ?? '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
          final guardAddr = activeAgent?.guardAddress ?? '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';

          return BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, dashState) {
              final metrics = dashState.metrics;
              final actions = dashState.recentActions;
              final spent = metrics?.todaySpentUsdc ?? 0.0;
              final cap = metrics?.dailyAutonomousCapUsdc ?? 2000.0;
              final burnPct = cap > 0 ? (spent / cap).clamp(0.0, 1.0) : 0.0;

              final totalToday = actions.length;
              final allowedToday = actions.where((a) =>
                  a.status == TreasuryActionStatus.executed ||
                  a.status == TreasuryActionStatus.approved).length;
              final escalatedToday = actions.where((a) => a.status == TreasuryActionStatus.pending).length;
              final blockedToday = actions.where((a) => a.status == TreasuryActionStatus.rejected).length;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Agent Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurfacePure,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.smart_toy_rounded,
                                  color: AppColors.brandPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeAgent?.name ?? 'Autonomous Treasury Agent',
                                      style: AppTextStyles.xl(context),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${activeAgent?.agentId ?? "agent_default_01"}',
                                      style: AppTextStyles.mono(
                                        context,
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isPaused ? AppColors.blockBackground : AppColors.allowBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isPaused ? AppColors.blockBorder : AppColors.allowBorder,
                                  ),
                                ),
                                child: Text(
                                  _isPaused ? 'PAUSED' : 'ACTIVE',
                                  style: AppTextStyles.xs(
                                    context,
                                    color: _isPaused ? AppColors.blockText : AppColors.allowText,
                                    fontWeight: AppTextStyles.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: AppColors.cardBorder),
                          const SizedBox(height: 14),
                          // Contract info
                          _buildCopyableField(
                            context,
                            'Gnosis Safe Multisig',
                            safeAddr,
                          ),
                          const SizedBox(height: 10),
                          _buildCopyableField(
                            context,
                            'Chapter2Guard Hook',
                            guardAddr,
                          ),
                          const SizedBox(height: 18),
                          // Kill Switch Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Emergency Kill Switch',
                                      style: AppTextStyles.sm(
                                        context,
                                        fontWeight: AppTextStyles.bold,
                                        color: _isPaused ? AppColors.blockText : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _isPaused
                                          ? 'Agent executions currently frozen'
                                          : 'Instantly pause all autonomous operations',
                                      style: AppTextStyles.xs(context),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: !_isPaused,
                                  activeThumbColor: AppColors.allow,
                                  inactiveThumbColor: AppColors.block,
                                  onChanged: (val) {
                                    setState(() => _isPaused = !val);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          !_isPaused
                                              ? 'Autonomous agent operations resumed'
                                              : 'EMERGENCY KILL SWITCH ENGAGED: Agent frozen',
                                        ),
                                        backgroundColor:
                                            !_isPaused ? AppColors.allow : AppColors.block,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Behavior metrics grid
                    Text(
                      'Today\'s Operational Telemetry',
                      style: AppTextStyles.sm(
                        context,
                        color: Colors.white,
                        fontWeight: AppTextStyles.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            'Total Actions',
                            totalToday.toString(),
                            Icons.receipt_long_rounded,
                            AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            'Allowed',
                            allowedToday.toString(),
                            Icons.check_circle_rounded,
                            AppColors.allow,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            'Escalated',
                            escalatedToday.toString(),
                            Icons.fingerprint_rounded,
                            AppColors.escalate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            'Blocked',
                            blockedToday.toString(),
                            Icons.cancel_rounded,
                            AppColors.block,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Cumulative daily burn rate card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurfacePure,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Spend Burn Rate',
                                style: AppTextStyles.md(context, fontWeight: AppTextStyles.semiBold),
                              ),
                              Text(
                                '\$${spent.toStringAsFixed(2)} / \$${cap.toStringAsFixed(0)} USDC',
                                style: AppTextStyles.sm(
                                  context,
                                  fontWeight: AppTextStyles.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: burnPct,
                              minHeight: 8,
                              backgroundColor: AppColors.cardSurface,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.allow),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(burnPct * 100).toStringAsFixed(1)}% consumed',
                                style: AppTextStyles.xs(context),
                              ),
                              Text(
                                '\$${(cap - spent).clamp(0, cap).toStringAsFixed(2)} remaining',
                                style: AppTextStyles.xs(context, color: AppColors.allowText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Allowed interaction types & whitelisted vendors
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurfacePure,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authorized Interaction Protocols',
                            style: AppTextStyles.md(context, fontWeight: AppTextStyles.semiBold),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildProtocolChip(context, 'x402 HTTP Paywall Protocol', true),
                              _buildProtocolChip(context, 'ERC-20 USDC Token Transfer', true),
                              _buildProtocolChip(context, 'Smart Contract Invocations', true),
                              _buildProtocolChip(context, 'Unchecked Arbitrary Calldata', false),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Whitelisted Enterprise APIs',
                            style: AppTextStyles.md(context, fontWeight: AppTextStyles.semiBold),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildVendorChip(context, 'Google Cloud Vertex AI'),
                              _buildVendorChip(context, 'Alchemy Node Infrastructure'),
                              _buildVendorChip(context, 'Amazon Web Services (AWS)'),
                              _buildVendorChip(context, 'OpenAI Platform API'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => MandateManagementSheet.show(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.actionPillBackground,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.tune_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Modify Mandate & Biometric Sign',
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
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurfacePure,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.lg(context, fontWeight: AppTextStyles.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.xs(context),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableField(BuildContext context, String label, String value) {
    final display = value.length > 14
        ? '${value.substring(0, 8)}...${value.substring(value.length - 6)}'
        : value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.sm(context, color: AppColors.textSecondary),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied $label: $value'),
                backgroundColor: AppColors.allow,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Row(
            children: [
              Text(
                display,
                style: AppTextStyles.mono(context, fontSize: 11, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded, size: 13, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolChip(BuildContext context, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.allowBackground : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.allowBorder : AppColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 14,
            color: active ? AppColors.allow : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.xs(
              context,
              color: active ? AppColors.allowText : AppColors.textMuted,
              fontWeight: AppTextStyles.medium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorChip(BuildContext context, String label) {
    return Chip(
      avatar: const Icon(Icons.verified_rounded, size: 14, color: AppColors.brandPrimary),
      label: Text(
        label,
        style: AppTextStyles.xs(context, fontWeight: AppTextStyles.medium),
      ),
      backgroundColor: AppColors.cardSurface,
      side: const BorderSide(color: AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
