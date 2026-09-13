import 'package:chapter2/features/world_id/cubit/world_id_approver_cubit.dart';
import 'package:chapter2/features/world_id/cubit/world_id_approver_state.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_state.dart';
import 'package:chapter2/shared/theme/app_colors.dart';
import 'package:chapter2/shared/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class WorldIdApproverCard extends StatelessWidget {
  const WorldIdApproverCard({
    super.key,
    this.onOpenLink,
  });

  final Future<void> Function(BuildContext context, String url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorldIdApproverCubit, WorldIdApproverState>(
      builder: (context, worldIdState) {
        final approvalsState = context.watch<X402ApprovalsCubit>().state;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, worldIdState),
              const SizedBox(height: 12),
              _buildBody(context, worldIdState, approvalsState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WorldIdApproverState state) {
    final isConfigured = state.isWorldIdConfigured;
    final isVerified = state.isVerified;

    Color iconColor = AppColors.textMuted;
    if (isConfigured) {
      iconColor = isVerified ? AppColors.allow : AppColors.escalate;
    }

    return Row(
      children: [
        Icon(Icons.fingerprint_rounded, color: iconColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'World ID Ledger Approver',
            style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.allowBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.allowBorder),
            ),
            child: Text(
              'Orb verified',
              style: AppTextStyles.xs(context, color: AppColors.allowText, fontWeight: AppTextStyles.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    WorldIdApproverState state,
    X402ApprovalsState approvalsState,
  ) {
    if (state.status == WorldIdApproverCubitStatus.loading && state.approverStatus == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!state.isWorldIdConfigured) {
      return Text(
        "World ID isn't configured on the backend.",
        style: AppTextStyles.sm(context, color: AppColors.textMuted),
      );
    }

    if (state.isVerified) {
      final expires = state.approverStatus?.expiresAt;
      final formattedExpiry = expires != null
          ? 'Expires: ${expires.toLocal().year}-${expires.toLocal().month.toString().padLeft(2, '0')}-${expires.toLocal().day.toString().padLeft(2, '0')}'
          : 'Active';
      return Text(
        formattedExpiry,
        style: AppTextStyles.sm(context, color: AppColors.allowText),
      );
    }

    final verification = state.verification;
    if (verification == null) {
      return _buildUnverifiedAction(context, state);
    }

    switch (verification.status) {
      case WorldIdOrbVerificationStatus.waitingForWorldApp:
      case WorldIdOrbVerificationStatus.awaitingConfirmation:
        return _buildWaitingOrAwaiting(context, state, verification);
      case WorldIdOrbVerificationStatus.verified:
        return _buildVerifiedState(context, state, verification, approvalsState);
      case WorldIdOrbVerificationStatus.bound:
        return const SizedBox.shrink();
      case WorldIdOrbVerificationStatus.failed:
      case WorldIdOrbVerificationStatus.expired:
        return _buildFailedOrExpired(context, state, verification);
    }
  }

  Widget _buildUnverifiedAction(BuildContext context, WorldIdApproverState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isWorldIdRequired) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.escalateBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.escalateBorder),
            ),
            child: Text(
              'Approvals are blocked until the Ledger approver is verified.',
              style: AppTextStyles.sm(context, color: AppColors.escalateText),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.read<WorldIdApproverCubit>().startOrbVerification(),
            icon: const Icon(Icons.verified_user_rounded, size: 18),
            label: const Text('Verify with World ID'),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingOrAwaiting(
    BuildContext context,
    WorldIdApproverState state,
    WorldIdOrbVerification verification,
  ) {
    final isWaiting = verification.status == WorldIdOrbVerificationStatus.waitingForWorldApp;
    final statusText = isWaiting ? 'Waiting for World ID' : 'Confirm in World ID';
    final isStaging = state.approverStatus?.environment == 'staging';
    final url = verification.connectorUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(statusText, style: AppTextStyles.sm(context, fontWeight: AppTextStyles.bold)),
          ],
        ),
        if (isStaging) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Open simulator.worldcoin.org in your browser, pick an Orb-verified identity, and paste this link.',
              style: AppTextStyles.xs(context, color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (url != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification link copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (onOpenLink != null) {
                      await onOpenLink!(context, url);
                      return;
                    }
                    try {
                      final uri = Uri.parse(url);
                      final launched = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open link. Please use Copy link.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open link. Please use Copy link.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open link'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            TextButton(
              onPressed: () => context.read<WorldIdApproverCubit>().cancelVerification(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerifiedState(
    BuildContext context,
    WorldIdApproverState state,
    WorldIdOrbVerification verification,
    X402ApprovalsState approvalsState,
  ) {
    final isLedgerReady = approvalsState.isLedgerReady;
    final isBinding = state.status == WorldIdApproverCubitStatus.binding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orb proof verified. Sign the binding on your Ledger.',
          style: AppTextStyles.sm(context, color: AppColors.allowText, fontWeight: AppTextStyles.bold),
        ),
        const SizedBox(height: 10),
        if (isLedgerReady)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBinding
                  ? null
                  : () async {
                      final approvalsCubit = context.read<X402ApprovalsCubit>();
                      await context.read<WorldIdApproverCubit>().bindWithLedger(
                            approvalsCubit.signPersonalMessageOnLedger,
                          );
                    },
              icon: isBinding
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Sign binding on Ledger'),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.blockBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blockBorder),
            ),
            child: Text(
              'Connect the approver Ledger above first',
              style: AppTextStyles.sm(context, color: AppColors.blockText),
            ),
          ),
      ],
    );
  }

  Widget _buildFailedOrExpired(
    BuildContext context,
    WorldIdApproverState state,
    WorldIdOrbVerification verification,
  ) {
    final isExpired = verification.status == WorldIdOrbVerificationStatus.expired;
    final text = isExpired ? 'Verification expired' : (verification.errorMessage ?? 'Verification failed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blockBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.blockBorder),
          ),
          child: Text(
            text,
            style: AppTextStyles.sm(context, color: AppColors.blockText),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.read<WorldIdApproverCubit>().startOrbVerification(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
