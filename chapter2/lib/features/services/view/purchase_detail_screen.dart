import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/remote/services_api_service.dart';
import 'package:chapter2/features/services/utils/purchase_status_presenter.dart';
import 'package:chapter2/features/shell/shell_tab_controller.dart';
import 'package:chapter2/features/x402_approvals/utils/usdc_amount_formatter.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Index of the Approvals tab inside [MainShellScreen], used by the
/// "Open Approvals" link on an ESCALATE status.
const _approvalsTabIndex = 2;
const _detailPollInterval = Duration(seconds: 3);

/// Polls one purchase request until it reaches a terminal status, and shows
/// the outcome: a vertical status timeline, the Guardian's reasons, and —
/// once PAID — the transaction hash and the service's own response.
@RoutePage()
class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({
    super.key,
    required this.purchaseRequestId,
    this.initialPurchase,
    ServicesApiService? apiService,
  }) : _apiService = apiService;

  final String purchaseRequestId;
  final PurchaseRequest? initialPurchase;
  final ServicesApiService? _apiService;

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late final ServicesApiService _apiService;
  PurchaseRequest? _purchase;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? locator<ServicesApiService>();
    _purchase = widget.initialPurchase;
    _startPolling();
  }

  void _startPolling() {
    _fetch();
    _pollingTimer = Timer.periodic(_detailPollInterval, (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final purchase = await _apiService.fetchPurchaseRequest(widget.purchaseRequestId);
      if (!mounted) return;
      setState(() {
        _purchase = purchase;
        _error = null;
      });
      if (purchase.status.isTerminal) {
        _pollingTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchase = _purchase;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(purchase?.serviceName ?? 'Purchase')),
      body: SafeArea(
        child: purchase == null ? _buildInitialLoadState(context) : _buildContent(context, purchase),
      ),
    );
  }

  Widget _buildInitialLoadState(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_error!, style: AppTextStyles.sm(context, color: AppColors.blockText)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildContent(BuildContext context, PurchaseRequest purchase) {
    final view = PurchaseStatusPresenter.describe(purchase);
    final headlineColor = _colorForTone(view.tone);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${UsdcAmountFormatter.format(purchase.amountAtomicUnits)} USDC',
                    style: AppTextStyles.xl(context),
                  ),
                  _buildStatusChip(context, purchase),
                ],
              ),
              const SizedBox(height: 18),
              _buildTimeline(context, view.steps),
              const SizedBox(height: 4),
              Text(view.headline, style: AppTextStyles.md(context, color: headlineColor, fontWeight: AppTextStyles.bold)),
              if (view.hint != null) ...[
                const SizedBox(height: 8),
                Text(view.hint!, style: AppTextStyles.sm(context, color: AppColors.textMuted)),
              ],
              if (view.reasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Guardian reasons', style: AppTextStyles.xs(context, fontWeight: AppTextStyles.bold)),
                const SizedBox(height: 6),
                ...view.reasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $reason', style: AppTextStyles.sm(context, color: headlineColor)),
                  ),
                ),
              ],
              if (view.showApprovalsCta) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      locator<ShellTabController>().value = _approvalsTabIndex;
                      context.router.popUntilRoot();
                    },
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: const Text('Open Approvals'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (purchase.status == PurchaseRequestStatus.paid) ...[
          const SizedBox(height: 14),
          _buildPaidCard(context, purchase),
        ],
        const SizedBox(height: 14),
        _buildRequestDetailsCard(context, purchase),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, PurchaseRequest purchase) {
    final chip = PurchaseStatusChip.forRequest(purchase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chip.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chip.border),
      ),
      child: Text(chip.label, style: AppTextStyles.xs(context, color: chip.textColor, fontWeight: AppTextStyles.bold)),
    );
  }

  Widget _buildTimeline(BuildContext context, List<PurchaseTimelineStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) _buildTimelineRow(context, steps[i], isLast: i == steps.length - 1),
      ],
    );
  }

  Widget _buildTimelineRow(BuildContext context, PurchaseTimelineStep step, {required bool isLast}) {
    final color = switch (step.state) {
      PurchaseTimelineStepState.done => AppColors.allow,
      PurchaseTimelineStepState.current => AppColors.primary,
      PurchaseTimelineStepState.pending => AppColors.textMuted,
      PurchaseTimelineStepState.error => AppColors.block,
    };
    final icon = switch (step.state) {
      PurchaseTimelineStepState.done => Icons.check_circle_rounded,
      PurchaseTimelineStepState.current => Icons.radio_button_checked_rounded,
      PurchaseTimelineStepState.pending => Icons.radio_button_unchecked_rounded,
      PurchaseTimelineStepState.error => Icons.cancel_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 18),
            if (!isLast) Container(width: 2, height: 24, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 1),
          child: Text(
            step.label,
            style: AppTextStyles.sm(
              context,
              color: step.state == PurchaseTimelineStepState.pending ? AppColors.textMuted : color,
              fontWeight: step.state == PurchaseTimelineStepState.pending ? AppTextStyles.regular : AppTextStyles.semiBold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaidCard(BuildContext context, PurchaseRequest purchase) {
    final txHash = purchase.transactionHash;
    final response = purchase.response;
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
          if (txHash != null) ...[
            _buildCopyableRow(context, 'Transaction', _shortenHash(txHash), txHash),
            InkWell(
              onTap: () => _copyToClipboard(context, 'Blockscout link', _blockscoutUrl(txHash)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('View on Blockscout', style: AppTextStyles.sm(context, color: AppColors.primary)),
                    ),
                    const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
          if (response != null && response.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Response', style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
            const SizedBox(height: 10),
            _buildKeyValueCard(context, response),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestDetailsCard(BuildContext context, PurchaseRequest purchase) {
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
          Text('Request', style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold)),
          const SizedBox(height: 12),
          _buildDetailRow(context, 'Resource', purchase.resourceUrl),
          _buildDetailRow(context, 'Agent', _shortenHash(purchase.agentAddress)),
          _buildDetailRow(context, 'Justification', purchase.justification),
          if (purchase.error != null && purchase.error!.isNotEmpty)
            _buildDetailRow(context, 'Error', purchase.error!, valueColor: AppColors.blockText),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.xs(context)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.sm(context, color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(BuildContext context, String label, String display, String fullValue) {
    return InkWell(
      onTap: () => _copyToClipboard(context, label, fullValue),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.sm(context)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(display, style: AppTextStyles.mono(context, fontSize: 12)),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in data.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: AppTextStyles.xs(context)),
                  Flexible(
                    child: Text(
                      _describeValue(entry.value),
                      style: AppTextStyles.mono(context, fontSize: 11),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _describeValue(dynamic value) {
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  Color _colorForTone(PurchaseStatusTone tone) {
    switch (tone) {
      case PurchaseStatusTone.allow:
        return AppColors.allowText;
      case PurchaseStatusTone.escalate:
        return AppColors.escalateText;
      case PurchaseStatusTone.block:
        return AppColors.blockText;
      case PurchaseStatusTone.neutral:
        return AppColors.textPrimary;
    }
  }

  String _blockscoutUrl(String txHash) => 'https://base-sepolia.blockscout.com/tx/$txHash';

  String _shortenHash(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label'), behavior: SnackBarBehavior.floating),
    );
  }
}
