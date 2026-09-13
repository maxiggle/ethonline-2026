import 'package:auto_route/auto_route.dart';
import 'package:chapter2/core/config/app_config.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/router/app_router.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/api/models/world_id_status.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_state.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _WorldIdLoadStatus { loading, loaded, unavailable }

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _WorldIdLoadStatus _worldIdStatus = _WorldIdLoadStatus.loading;
  WorldIdStatus? _worldId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<X402ApprovalsCubit>().loadConfig();
      _loadWorldIdStatus();
    });
  }

  Future<void> _loadWorldIdStatus() async {
    final walletAddress = context.read<AuthCubit>().state.user?.walletAddress;
    if (walletAddress == null || walletAddress.isEmpty) {
      setState(() => _worldIdStatus = _WorldIdLoadStatus.unavailable);
      return;
    }
    try {
      final status = await locator<Chapter2ApiService>().fetchWorldIdStatus(walletAddress);
      if (!mounted) return;
      setState(() {
        _worldId = status;
        _worldIdStatus = _WorldIdLoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _worldIdStatus = _WorldIdLoadStatus.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final user = authState.user;
          final wallet = user?.walletAddress ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionCard(
                  context,
                  title: 'Account',
                  icon: Icons.person_pin_rounded,
                  children: [
                    _buildInfoRow(context, 'Name', user?.name ?? 'Not set'),
                    const Divider(height: 16, color: AppColors.border),
                    _buildInfoRow(context, 'Email', user?.email ?? 'Not set'),
                    const Divider(height: 16, color: AppColors.border),
                    _buildInfoRow(
                      context,
                      'Privy wallet',
                      wallet.isNotEmpty ? wallet : 'Not available',
                      isMonospace: wallet.isNotEmpty,
                      canCopy: wallet.isNotEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Backend',
                  icon: Icons.dns_rounded,
                  children: [
                    _buildInfoRow(context, 'Base URL', AppConfig.backendBaseUrl),
                    const Divider(height: 16, color: AppColors.border),
                    BlocBuilder<X402ApprovalsCubit, X402ApprovalsState>(
                      builder: (context, state) {
                        if (state.config != null) {
                          return _buildInfoRow(
                            context,
                            'Ledger approver',
                            state.config!.approverAddress,
                            isMonospace: true,
                            canCopy: true,
                          );
                        }
                        if (state.status == X402ApprovalsStatus.failure) {
                          return _buildErrorRow(
                            context,
                            state.errorMessage ?? 'Could not load the approver config.',
                            onRetry: () => context.read<X402ApprovalsCubit>().loadConfig(),
                          );
                        }
                        return _buildLoadingRow(context, 'Loading approver config...');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'World ID',
                  icon: Icons.verified_user_rounded,
                  children: [_buildWorldIdRow(context)],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Account & Privacy',
                  icon: Icons.shield_outlined,
                  children: [
                    Text(
                      'Historical transaction records and on-chain proofs remain preserved on Base Sepolia after deletion.',
                      style: AppTextStyles.xs(context, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => _showDeleteConfirmation(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.block,
                        side: BorderSide(color: AppColors.blockBorder),
                      ),
                      child: const Text('Delete account'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<AuthCubit>().logout();
                    if (context.mounted) {
                      context.router.replaceAll([LoginRoute()]);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorldIdRow(BuildContext context) {
    switch (_worldIdStatus) {
      case _WorldIdLoadStatus.loading:
        return _buildLoadingRow(context, 'Checking World ID status...');
      case _WorldIdLoadStatus.unavailable:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Status', style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
            Text('Not configured', style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold)),
          ],
        );
      case _WorldIdLoadStatus.loaded:
        final isVerified = _worldId?.isVerified ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Status', style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isVerified ? AppColors.allowBackground : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isVerified ? AppColors.allowBorder : AppColors.border),
              ),
              child: Text(
                isVerified ? 'Verified' : 'Not verified',
                style: AppTextStyles.xs(
                  context,
                  color: isVerified ? AppColors.allowText : AppColors.textSecondary,
                  fontWeight: AppTextStyles.bold,
                ),
              ),
            ),
          ],
        );
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your autonomous agent will be deactivated and your account removed from Privy Cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.block),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<AuthCubit>().deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        context.router.replaceAll([LoginRoute()]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
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
    bool canCopy = false,
  }) {
    final display = (isMonospace && value.length > 16)
        ? '${value.substring(0, 8)}...${value.substring(value.length - 6)}'
        : value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  display,
                  style: isMonospace
                      ? AppTextStyles.mono(context, fontSize: 11)
                      : AppTextStyles.sm(context, fontWeight: AppTextStyles.medium),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $label')),
                    );
                  },
                  child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingRow(BuildContext context, String label) {
    return Row(
      children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.sm(context, color: AppColors.textSecondary)),
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
}
