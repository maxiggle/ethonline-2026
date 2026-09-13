import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_state.dart';
import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/utils/usdc_amount_formatter.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

/// Lets a remote tester with a Nano X / Flex connect over Bluetooth and
/// approve or reject escalated x402 payments directly on the device.
@RoutePage()
class X402ApprovalsScreen extends StatefulWidget {
  const X402ApprovalsScreen({super.key});

  @override
  State<X402ApprovalsScreen> createState() => _X402ApprovalsScreenState();
}

class _X402ApprovalsScreenState extends State<X402ApprovalsScreen> {
  X402ApprovalsCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<X402ApprovalsCubit>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<X402ApprovalsCubit>();
      cubit.loadConfig();
      cubit.startPolling();
    });
  }

  @override
  void dispose() {
    // Read the cubit via the cached reference, not `context.read`: by the
    // time dispose() runs the BlocProvider ancestor may already be
    // deactivated (e.g. when the whole tree is torn down together).
    _cubit?.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ledger Approvals')),
      body: BlocConsumer<X402ApprovalsCubit, X402ApprovalsState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            (current.status == X402ApprovalsStatus.success || current.status == X402ApprovalsStatus.failure),
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.status == X402ApprovalsStatus.success) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  state.lastCompletedActionId != null
                      ? 'Submitted the Ledger signature for ${state.lastCompletedActionId}'
                      : 'Submitted the Ledger signature',
                ),
                backgroundColor: AppColors.allow,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state.status == X402ApprovalsStatus.failure && state.errorMessage != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.block,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLedgerConnectionCard(context, state),
                const SizedBox(height: 16),
                _buildBlindSigningHint(context),
                const SizedBox(height: 16),
                Text(
                  'Pending Escalations',
                  style: AppTextStyles.lg(context, color: Colors.white),
                ),
                const SizedBox(height: 12),
                if (state.pendingApprovals.isEmpty)
                  _buildEmptyState(context)
                else
                  ...state.pendingApprovals.map(
                    (approval) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPendingApprovalCard(context, state, approval),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlindSigningHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.escalateBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.escalateBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.escalateText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'On the Ledger you will see the domain and message hashes; '
              'Blind signing must be enabled in the Ethereum app.',
              style: AppTextStyles.sm(context, color: AppColors.escalateText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerConnectionCard(BuildContext context, X402ApprovalsState state) {
    final isConnected = state.connectedAddress != null;
    final isConnecting = state.status == X402ApprovalsStatus.connecting;

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
          Row(
            children: [
              Icon(
                Icons.usb_rounded,
                color: isConnected
                    ? (state.matchesApprover ? AppColors.allow : AppColors.block)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isConnected ? 'Ledger connected' : 'No Ledger connected',
                  style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isConnecting ? null : () => _openDeviceScanSheet(context),
              icon: isConnecting
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded, size: 18),
              label: Text(isConnected ? 'Reconnect' : 'Connect Ledger'),
            ),
          ),
          if (isConnected) ...[
            const SizedBox(height: 10),
            Text(
              state.connectedAddress!,
              style: AppTextStyles.mono(context, fontSize: 12),
            ),
            if (!state.matchesApprover) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.blockBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blockBorder),
                ),
                child: Text(
                  'This Ledger is not the configured approver'
                  '${state.config != null ? ' (${state.config!.approverAddress})' : ''}. '
                  'Send the address above to the backend owner.',
                  style: AppTextStyles.sm(context, color: AppColors.blockText),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No escalated payments are awaiting a signature right now.',
        style: AppTextStyles.sm(context),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPendingApprovalCard(
    BuildContext context,
    X402ApprovalsState state,
    PendingX402Approval approval,
  ) {
    final isExpired = approval.isExpired;
    final isLedgerReady = state.isLedgerReady;
    final isBusy = state.status == X402ApprovalsStatus.awaitingDevice && state.awaitingActionId == approval.actionId;
    final canAct = isLedgerReady && !isExpired && !isBusy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isExpired ? AppColors.blockBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  approval.resourceUrl,
                  style: AppTextStyles.md(context, fontWeight: AppTextStyles.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.escalateBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.escalateBorder),
                ),
                child: Text(
                  'RISK ${approval.riskScore}',
                  style: AppTextStyles.xs(context, color: AppColors.escalateText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '\$${UsdcAmountFormatter.format(approval.amountAtomicUnits)} USDC',
            style: AppTextStyles.xl(context),
          ),
          const SizedBox(height: 8),
          _buildDetailRow(context, 'Payee', approval.payTo, isAddress: true),
          _buildDetailRow(context, 'Agent', approval.agentAddress, isAddress: true),
          _buildDetailRow(
            context,
            'Expires',
            isExpired ? 'Expired' : _formatCountdown(approval.validBefore),
            valueColor: isExpired ? AppColors.blockText : null,
          ),
          if (approval.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Guardian reasons', style: AppTextStyles.xs(context)),
            const SizedBox(height: 4),
            ...approval.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $reason', style: AppTextStyles.sm(context)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canAct ? () => context.read<X402ApprovalsCubit>().reject(approval.actionId) : null,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.block),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: canAct ? () => context.read<X402ApprovalsCubit>().approve(approval.actionId) : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.allow, foregroundColor: Colors.white),
                  child: isBusy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool isAddress = false,
  }) {
    final display = isAddress ? _shortenAddress(value) : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.sm(context)),
          Flexible(
            child: isAddress
                ? InkWell(
                    onTap: () => _copyToClipboard(context, label, value),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          display,
                          style: AppTextStyles.mono(context, fontSize: 11, color: valueColor),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
                      ],
                    ),
                  )
                : Text(
                    display,
                    style: AppTextStyles.mono(context, fontSize: 11, color: valueColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label'), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatCountdown(DateTime validBefore) {
    final remaining = validBefore.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours >= 1) return 'in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    if (remaining.inMinutes >= 1) return 'in ${remaining.inMinutes}m';
    return 'in ${remaining.inSeconds}s';
  }

  void _openDeviceScanSheet(BuildContext context) {
    final cubit = context.read<X402ApprovalsCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nearby Ledger devices',
                  style: AppTextStyles.lg(sheetContext, fontWeight: AppTextStyles.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlock your Ledger and open the Ethereum app before connecting.',
                  style: AppTextStyles.sm(sheetContext),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _DiscoveredDevicesList(
                    stream: cubit.scanForDevices(),
                    onDeviceTapped: (device) async {
                      Navigator.of(sheetContext).pop();
                      await cubit.stopScanning();
                      await cubit.connectLedger(device);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => cubit.stopScanning());
  }
}

class _DiscoveredDevicesList extends StatefulWidget {
  const _DiscoveredDevicesList({required this.stream, required this.onDeviceTapped});

  final Stream<LedgerDevice> stream;
  final ValueChanged<LedgerDevice> onDeviceTapped;

  @override
  State<_DiscoveredDevicesList> createState() => _DiscoveredDevicesListState();
}

class _DiscoveredDevicesListState extends State<_DiscoveredDevicesList> {
  final List<LedgerDevice> _devices = [];
  late final StreamSubscription<LedgerDevice> _subscription;
  Object? _scanError;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(
      (device) {
        setState(() {
          if (!_devices.any((existing) => existing.id == device.id)) {
            _devices.add(device);
          }
        });
      },
      onError: (Object error) => setState(() => _scanError = error),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scanError != null) {
      return Center(
        child: Text(
          'Bluetooth scan failed: $_scanError',
          style: AppTextStyles.sm(context, color: AppColors.blockText),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      itemCount: _devices.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth_rounded, color: AppColors.ledgerOrange),
          title: Text(device.name.isNotEmpty ? device.name : device.id, style: AppTextStyles.md(context)),
          subtitle: Text(device.id, style: AppTextStyles.mono(context, fontSize: 10)),
          onTap: () => widget.onDeviceTapped(device),
        );
      },
    );
  }
}
