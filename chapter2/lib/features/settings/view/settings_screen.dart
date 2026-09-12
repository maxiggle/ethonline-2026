import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: Text(
          'Settings & Infrastructure',
          style: AppTextStyles.xl(context, color: Colors.white),
        ),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final user = authState.user;
          final wallet = user?.walletAddress ?? '';
          final agents = authState.agents;
          final activeAgent = agents.isNotEmpty ? agents.first : null;
          final safeAddr =
              activeAgent?.safeAddress ??
              '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
          final guardAddr =
              activeAgent?.guardAddress ??
              '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity & Biometric Section
                _buildSectionCard(
                  context,
                  title: 'Connected Identity',
                  icon: Icons.person_pin_rounded,
                  children: [
                    _buildInfoRow(
                      context,
                      'Operator Email',
                      user?.email ?? 'operator@chapter2.finance',
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildInfoRow(
                      context,
                      'Privy Embedded EVM',
                      wallet.isNotEmpty ? wallet : 'Generating wallet...',
                      isMonospace: true,
                      canCopy: wallet.isNotEmpty,
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildInfoRow(
                      context,
                      'Privy DID',
                      user?.id ?? 'did:privy:anonymous',
                      isMonospace: true,
                      canCopy: true,
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'World ID Verification',
                          style: AppTextStyles.sm(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.allowBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.allowBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                size: 13,
                                color: AppColors.allow,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verified Human (Orb)',
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
                const SizedBox(height: 16),
                // Smart Contracts & Network
                _buildSectionCard(
                  context,
                  title: 'Smart Contract Infrastructure',
                  icon: Icons.account_balance_wallet_rounded,
                  children: [
                    _buildInfoRow(
                      context,
                      'Execution Network',
                      'Base Sepolia (Chain ID 84532)',
                      isHighlight: true,
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildInfoRow(
                      context,
                      'Gnosis Safe Multisig',
                      safeAddr,
                      isMonospace: true,
                      canCopy: true,
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildInfoRow(
                      context,
                      'Chapter2Guard Hook',
                      guardAddr,
                      isMonospace: true,
                      canCopy: true,
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RPC Endpoint Status',
                          style: AppTextStyles.sm(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.allow,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live (Alchemy 38ms)',
                              style: AppTextStyles.xs(
                                context,
                                color: AppColors.allowText,
                                fontWeight: AppTextStyles.semiBold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Hardware & Security Policies
                _buildSectionCard(
                  context,
                  title: 'Hardware & Security',
                  icon: Icons.shield_rounded,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ledger Hardware Signer',
                          style: AppTextStyles.sm(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD6B8)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bluetooth_connected_rounded,
                                size: 13,
                                color: AppColors.ledgerOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nano X (BLE Ready)',
                                style: AppTextStyles.xs(
                                  context,
                                  color: AppColors.ledgerOrange,
                                  fontWeight: AppTextStyles.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildInfoRow(
                      context,
                      'Guardian Engine Version',
                      'Chapter2 Guard v1.0.4-sepolia',
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildInfoRow(
                      context,
                      'Policy Synchronization',
                      'Continuous Real-Time Webhook',
                    ),
                    const Divider(height: 16, color: AppColors.cardBorder),
                    InkWell(
                      onTap: () {
                        context.router.push(OnboardingRoute());
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Review Onboarding Wizard',
                              style: AppTextStyles.sm(
                                context,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '4 Steps',
                                  style: AppTextStyles.xs(
                                    context,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: AppColors.brandPrimary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Danger Zone / Account Deletion
                _buildSectionCard(
                  context,
                  title: 'Account & Privacy',
                  icon: Icons.shield_outlined,
                  children: [
                    Text(
                      'Permanently remove your identity from Privy Cloud and deactivate all autonomous agents. Historical transaction records, audit receipts, and on-chain proofs remain preserved on Base Sepolia.',
                      style: AppTextStyles.xs(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => _showDeleteConfirmation(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.block,
                        side: const BorderSide(color: AppColors.blockBorder),
                        backgroundColor: AppColors.blockBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.delete_forever_rounded,
                            size: 18,
                            color: AppColors.block,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Account & Deactivate Agents',
                            style: AppTextStyles.sm(
                              context,
                              color: AppColors.block,
                              fontWeight: AppTextStyles.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Sign Out Button
                ElevatedButton(
                  onPressed: () async {
                    await context.read<AuthCubit>().logout();
                    onSignOut?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.screenBackgroundElevated,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.actionPillBorder),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Disconnect Session & Sign Out',
                        style: AppTextStyles.md(
                          context,
                          color: AppColors.textPrimary,
                          fontWeight: AppTextStyles.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurfacePure,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.blockBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.blockBorder),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.block,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Account?',
              style: AppTextStyles.lg(
                dialogContext,
                color: Colors.white,
                fontWeight: AppTextStyles.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your Chapter2 account? Your autonomous agent will be deactivated, and your account will be removed from Privy Cloud.',
              style: AppTextStyles.sm(
                dialogContext,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.screenBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                'Audit Guarantee: Historical on-chain execution receipts and audit logs will remain intact on Base Sepolia.',
                style: AppTextStyles.xs(
                  dialogContext,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.sm(
                dialogContext,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.block,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Delete Account',
              style: AppTextStyles.sm(
                dialogContext,
                color: Colors.white,
                fontWeight: AppTextStyles.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting account and deactivating agent...'),
              ],
            ),
            duration: Duration(seconds: 10),
            backgroundColor: AppColors.cardSurfacePure,
            behavior: SnackBarBehavior.floating,
          ),
        );

        await context.read<AuthCubit>().deleteAccount();

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: AppColors.allow,
              behavior: SnackBarBehavior.floating,
            ),
          );
          onSignOut?.call();
          context.router.replaceAll([LoginRoute()]);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: AppColors.block,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurfacePure,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.md(
                  context,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isMonospace = false,
    bool isHighlight = false,
    bool canCopy = false,
  }) {
    final display = (isMonospace && value.length > 16)
        ? '${value.substring(0, 8)}...${value.substring(value.length - 6)}'
        : value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.sm(context, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  display,
                  style: isMonospace
                      ? AppTextStyles.mono(
                          context,
                          fontSize: 11,
                          color: AppColors.brandPrimary,
                        )
                      : (isHighlight
                            ? AppTextStyles.sm(
                                context,
                                fontWeight: AppTextStyles.bold,
                                color: AppColors.textPrimary,
                              )
                            : AppTextStyles.sm(
                                context,
                                fontWeight: AppTextStyles.medium,
                                color: AppColors.textPrimary,
                              )),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 6),
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
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
