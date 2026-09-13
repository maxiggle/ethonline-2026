import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_state.dart';
import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/remote/x402_approvals_api_service.dart';
import 'package:chapter2/features/x402_approvals/eip712/eip712_hasher.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ble_client.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ethereum_signer.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_status_word.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

const _rejectMessagePrefix = 'chapter2-reject:';
const _pendingPollInterval = Duration(seconds: 3);

/// Drives Ledger BLE approvals for escalated x402 payments: connects to a
/// Nano X / Flex over Bluetooth, verifies its address against the backend's
/// configured `LEDGER_APPROVER_ADDRESS`, and signs approve/reject requests on
/// the device.
class X402ApprovalsCubit extends Cubit<X402ApprovalsState> {
  X402ApprovalsCubit({
    required X402ApprovalsApiService apiService,
    required LedgerBleClient ledgerBleClient,
  })  : _apiService = apiService,
        _ledgerBleClient = ledgerBleClient,
        super(const X402ApprovalsState());

  final X402ApprovalsApiService _apiService;
  final LedgerBleClient _ledgerBleClient;

  LedgerEthereumSigner? _signer;
  Timer? _pollingTimer;

  Stream<LedgerDevice> scanForDevices() => _ledgerBleClient.scan();

  Future<void> stopScanning() => _ledgerBleClient.stopScanning();

  Future<void> loadConfig() async {
    try {
      final config = await _apiService.fetchApprovalConfig();
      emit(state.copyWith(config: config, clearErrorMessage: true));
    } catch (error) {
      emit(state.copyWith(status: X402ApprovalsStatus.failure, errorMessage: _describeError(error)));
    }
  }

  /// Starts polling `pending` every 3 seconds. Call [stopPolling] when the
  /// approvals screen is no longer visible.
  void startPolling() {
    _pollingTimer?.cancel();
    unawaited(refreshPendingApprovals());
    _pollingTimer = Timer.periodic(_pendingPollInterval, (_) => refreshPendingApprovals());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> refreshPendingApprovals() async {
    try {
      final pending = await _apiService.fetchPendingApprovals();
      emit(state.copyWith(pendingApprovals: pending));
    } catch (error) {
      emit(state.copyWith(errorMessage: _describeError(error)));
    }
  }

  Future<void> connectLedger(LedgerDevice device) async {
    final config = state.config;
    if (config == null) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: 'The approval config has not loaded yet',
      ));
      return;
    }

    emit(state.copyWith(status: X402ApprovalsStatus.connecting, clearErrorMessage: true));
    try {
      final signer = await _ledgerBleClient.connectSigner(device);
      final address = await signer.getAddress();

      _signer = signer;

      final matchesApprover = _isSameAddress(address, config.approverAddress);
      emit(state.copyWith(
        status: X402ApprovalsStatus.connected,
        connectedAddress: address,
        matchesApprover: matchesApprover,
        errorMessage: matchesApprover
            ? null
            : 'This Ledger ($address) is not the configured approver (${config.approverAddress})',
        clearErrorMessage: matchesApprover,
      ));
    } catch (error) {
      emit(state.copyWith(status: X402ApprovalsStatus.failure, errorMessage: _describeError(error)));
    }
  }

  Future<void> approve(String actionId) async {
    final signer = _signer;
    if (signer == null || !state.isLedgerReady) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: 'Connect a matching Ledger before approving',
      ));
      return;
    }

    final approval = _findPendingApproval(actionId);
    if (approval == null) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: 'Pending approval $actionId is no longer available',
      ));
      return;
    }
    if (approval.isExpired) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: 'This payment authorization has expired; the agent must request payment again',
      ));
      return;
    }

    emit(state.copyWith(
      status: X402ApprovalsStatus.awaitingDevice,
      awaitingActionId: actionId,
      awaitingMessage: 'Confirm on your Ledger',
      clearErrorMessage: true,
    ));

    try {
      final hashes = Eip712Hasher.hash(approval.typedData);
      final signature = await signer.signEip712Hashed(
        domainSeparator: hashes.domainSeparator,
        messageHash: hashes.messageHash,
      );
      await _apiService.submitApprovalSignature(actionId: actionId, signature: signature.toHex());
      emit(state.copyWith(
        status: X402ApprovalsStatus.success,
        lastCompletedActionId: actionId,
        clearAwaitingActionId: true,
      ));
      await refreshPendingApprovals();
    } catch (error) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: _describeError(error),
        clearAwaitingActionId: true,
      ));
    }
  }

  Future<void> reject(String actionId) async {
    final signer = _signer;
    if (signer == null || !state.isLedgerReady) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: 'Connect a matching Ledger before rejecting',
      ));
      return;
    }

    emit(state.copyWith(
      status: X402ApprovalsStatus.awaitingDevice,
      awaitingActionId: actionId,
      awaitingMessage: 'Confirm rejection on your Ledger',
      clearErrorMessage: true,
    ));

    try {
      final message = Uint8List.fromList(utf8.encode('$_rejectMessagePrefix$actionId'));
      final signature = await signer.signPersonalMessage(message);
      await _apiService.submitRejectionSignature(actionId: actionId, signature: signature.toHex());
      emit(state.copyWith(
        status: X402ApprovalsStatus.success,
        lastCompletedActionId: actionId,
        clearAwaitingActionId: true,
      ));
      await refreshPendingApprovals();
    } catch (error) {
      emit(state.copyWith(
        status: X402ApprovalsStatus.failure,
        errorMessage: _describeError(error),
        clearAwaitingActionId: true,
      ));
    }
  }

  PendingX402Approval? _findPendingApproval(String actionId) {
    for (final approval in state.pendingApprovals) {
      if (approval.actionId == actionId) return approval;
    }
    return null;
  }

  bool _isSameAddress(String a, String b) => a.toLowerCase() == b.toLowerCase();

  String _describeError(Object error) {
    if (error is LedgerStatusWordException) return error.message;
    return error.toString();
  }

  @override
  Future<void> close() async {
    stopPolling();
    _signer = null;
    try {
      await _ledgerBleClient.disconnect();
    } catch (_) {
      // Already disconnected or the device went away; nothing more to do.
    }
    return super.close();
  }
}
