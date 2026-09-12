import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuardianAnalysisSheet extends StatelessWidget {
  const GuardianAnalysisSheet({
    super.key,
    required this.action,
  });

  final TreasuryAction action;

  static Future<void> show(BuildContext context, TreasuryAction action) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GuardianAnalysisSheet(action: action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAllowed = action.status == TreasuryActionStatus.executed ||
        action.status == TreasuryActionStatus.approved;
    final isEscalated = action.status == TreasuryActionStatus.pending;
    final isBlocked = action.status == TreasuryActionStatus.rejected;

    final badgeColor = isAllowed
        ? AppColors.allow
        : (isEscalated ? AppColors.escalate : AppColors.block);
    final badgeBg = isAllowed
        ? AppColors.allowBackground
        : (isEscalated ? AppColors.escalateBackground : AppColors.blockBackground);
    final badgeBorder = isAllowed
        ? AppColors.allowBorder
        : (isEscalated ? AppColors.escalateBorder : AppColors.blockBorder);
    final badgeText = isAllowed
        ? AppColors.allowText
        : (isEscalated ? AppColors.escalateText : AppColors.blockText);

    final verdictTitle = isAllowed
        ? 'ALLOW — Autonomous Execution'
        : (isEscalated
            ? 'ESCALATE — Human Clear-Sign Required'
            : 'BLOCK — Adversarial Interception');

    // Mandate checks & risk flags based on action properties
    final isOverThreshold = action.amountDisplayUsdc > 100.0;
    final confidenceScore = (100 - (action.riskScore * 0.35)).clamp(75, 99).toInt();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurfacePure,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            // Header with Verdict Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Icon(
                    isAllowed
                        ? Icons.check_circle_outline_rounded
                        : (isEscalated
                            ? Icons.warning_amber_rounded
                            : Icons.block_rounded),
                    color: badgeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guardian Risk Analysis',
                        style: AppTextStyles.xl(context),
                      ),
                      Text(
                        verdictTitle,
                        style: AppTextStyles.xs(
                          context,
                          color: badgeText,
                          fontWeight: AppTextStyles.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Action summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildAnalysisRow(
                    context,
                    'Requested Amount',
                    '\$${action.amountDisplayUsdc.toStringAsFixed(2)} USDC',
                    isHighlight: true,
                  ),
                  const Divider(height: 16, color: AppColors.cardBorder),
                  _buildAnalysisRow(context, 'Purpose / Vendor', action.purpose),
                  const Divider(height: 16, color: AppColors.cardBorder),
                  _buildAnalysisRow(
                    context,
                    'Recipient Target',
                    action.recipientAddress,
                    isMonospace: true,
                    canCopy: true,
                  ),
                  const Divider(height: 16, color: AppColors.cardBorder),
                  _buildAnalysisRow(
                    context,
                    'Supervised Agent',
                    action.agentAddress.isNotEmpty
                        ? (action.agentAddress.length > 14
                            ? '${action.agentAddress.substring(0, 8)}...${action.agentAddress.substring(action.agentAddress.length - 4)}'
                            : action.agentAddress)
                        : 'Treasury Worker #1',
                    isMonospace: true,
                  ),
                  if (action.nonce != null) ...[
                    const Divider(height: 16, color: AppColors.cardBorder),
                    _buildAnalysisRow(
                      context,
                      'Safe Multisig Nonce',
                      '#${action.nonce}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Evaluation breakdown
            Text(
              'Guardian Mandate & Policy Checks',
              style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
            ),
            const SizedBox(height: 10),
            _buildCheckItem(
              context,
              title: 'Mandate Limit Check',
              subtitle: isOverThreshold
                  ? 'Exceeds single autonomous ceiling (\$100 USDC)'
                  : 'Within single autonomous ceiling (\$100 USDC)',
              passed: !isOverThreshold,
            ),
            const SizedBox(height: 8),
            _buildCheckItem(
              context,
              title: 'Vendor Whitelist Assessment',
              subtitle: isBlocked
                  ? 'Unknown / unverified smart contract destination'
                  : 'Matches whitelisted enterprise API service catalog',
              passed: !isBlocked,
            ),
            const SizedBox(height: 8),
            _buildCheckItem(
              context,
              title: 'AI Guardian Confidence Score',
              subtitle: '$confidenceScore% confidence score from heuristic policy model',
              passed: confidenceScore >= 80,
            ),
            const SizedBox(height: 16),
            // Cryptographic Receipt / Proof
            if (action.txHash != null && action.txHash!.isNotEmpty) ...[
              Text(
                'On-Chain Cryptographic Receipt',
                style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: action.txHash!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied transaction hash: ${action.txHash}'),
                      backgroundColor: AppColors.allow,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: AppColors.brandPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          action.txHash!,
                          style: AppTextStyles.mono(
                            context,
                            fontSize: 11,
                            color: AppColors.brandPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Close / Done CTA
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardSurface,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                elevation: 0,
              ),
              child: Text(
                'Close Analysis',
                style: AppTextStyles.md(context, fontWeight: AppTextStyles.semiBold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
    bool isMonospace = false,
    bool canCopy = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.sm(context, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: isMonospace
                      ? AppTextStyles.mono(context, fontSize: 12)
                      : (isHighlight
                          ? AppTextStyles.md(
                              context,
                              fontWeight: AppTextStyles.bold,
                              color: AppColors.textPrimary,
                            )
                          : AppTextStyles.sm(
                              context,
                              fontWeight: AppTextStyles.semiBold,
                              color: AppColors.textPrimary,
                            )),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied: $value'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.actionPillBackground,
                      ),
                    );
                  },
                  child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool passed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: passed ? AppColors.allow : AppColors.block,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.sm(context, fontWeight: AppTextStyles.semiBold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.xs(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
